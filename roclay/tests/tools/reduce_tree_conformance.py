#!/usr/bin/env python3
"""Greedily reduce a generated recursive Roclay/Clay mismatch.

The predicate preserves a caller-selected minimum rectangle delta, preventing
a material failure from drifting into an unrelated subpixel discrepancy.
"""

from __future__ import annotations

import argparse
import os
import random
import re
import shutil
import subprocess
from dataclasses import replace
from pathlib import Path
from typing import Iterable

from generate_flat_conformance import AxisSizing, bounds, number, parse_oracle
from generate_tree_conformance import (
    BoxConfig,
    Node,
    TreeCase,
    generate_case,
    generate_source,
    wire_case,
)


RECT_LINE = re.compile(
    r"^\s*(expected|actual)\s+"
    r"(-?[0-9.]+)\s+(-?[0-9.]+)\s+(-?[0-9.]+)\s+(-?[0-9.]+)\s*$"
)


def make_axis(kind: int, value: float = 0, minimum: float = 0, maximum: float = 0) -> AxisSizing:
    range_roc = (
        "Roclay.unbounded"
        if minimum == 0 and maximum == 0
        else bounds(None if minimum == 0 else minimum, None if maximum == 0 else maximum)
    )
    if kind == 0:
        roc = f"Fit({range_roc})"
    elif kind == 1:
        roc = f"Fixed({number(value)})"
        minimum = value
        maximum = value
    elif kind == 2:
        roc = f"Fill({range_roc})"
    else:
        roc = f"Percent({number(value)})"
        minimum = 0
        maximum = 0
    return AxisSizing(kind, value, minimum, maximum, roc)


def axis_complexity(axis: AxisSizing) -> int:
    tag_cost = (0, 3, 2, 4)[axis.kind]
    return tag_cost * 1000 + round(abs(axis.value) * 100) + round(abs(axis.minimum) * 10) + round(abs(axis.maximum) * 10)


def config_complexity(config: BoxConfig) -> int:
    scalars = (
        config.padding_left,
        config.padding_right,
        config.padding_top,
        config.padding_bottom,
        config.gap,
        config.align_x,
        config.align_y,
        config.child_offset_x,
        config.child_offset_y,
    )
    return (
        config.direction * 100
        + sum(abs(value) for value in scalars)
        + (100 if config.clip_horizontal else 0)
        + (100 if config.clip_vertical else 0)
        + axis_complexity(config.width_sizing)
        + axis_complexity(config.height_sizing)
    )


def node_complexity(node: Node) -> int:
    own = 100_000 + config_complexity(node.config)
    if node.aspect is not None:
        own += 1000 + round(abs(node.aspect) * 100)
    if node.kind == "intrinsic":
        own += abs(node.intrinsic_width) + abs(node.intrinsic_height)
    elif node.kind == "text":
        own += (
            len(node.text) * 10
            + node.text_wrap_mode * 100
            + node.text_align * 20
            + node.font_size * 10
            + node.line_height * 10
        )
    return own + sum(node_complexity(child) for child in node.children)


def case_complexity(case: TreeCase) -> int:
    return node_complexity(case.root) + case.root_width + case.root_height


def node_count(node: Node) -> int:
    return 1 + sum(node_count(child) for child in node.children)


def paths(node: Node, prefix: tuple[int, ...] = ()) -> list[tuple[int, ...]]:
    found = [prefix]
    for index, child in enumerate(node.children):
        found.extend(paths(child, (*prefix, index)))
    return found


def node_at(node: Node, path: tuple[int, ...]) -> Node:
    current = node
    for index in path:
        current = current.children[index]
    return current


def replace_node(node: Node, path: tuple[int, ...], replacement: Node) -> Node:
    if not path:
        return replacement
    index = path[0]
    children = list(node.children)
    children[index] = replace_node(children[index], path[1:], replacement)
    return replace(node, children=tuple(children))


def case_with_node(case: TreeCase, path: tuple[int, ...], replacement: Node) -> TreeCase:
    return replace(case, root=replace_node(case.root, path, replacement))


def unique(values: Iterable[object]) -> Iterable[object]:
    seen: set[object] = set()
    for value in values:
        if value not in seen:
            seen.add(value)
            yield value


def smaller_numbers(value: int, *, allow_zero: bool = True) -> Iterable[int]:
    candidates = [0] if allow_zero else []
    candidates.extend([1, value // 2])
    return (candidate for candidate in unique(candidates) if candidate != value and (allow_zero or candidate > 0))


def axis_candidates(axis: AxisSizing) -> Iterable[AxisSizing]:
    candidates: list[AxisSizing] = []
    if axis.kind == 1:
        candidates.extend(make_axis(1, value) for value in smaller_numbers(int(axis.value), allow_zero=False))
    elif axis.kind == 3:
        candidates.extend([make_axis(3, 0.5), make_axis(3, 0.1)])
    else:
        candidates.append(make_axis(axis.kind))
        if axis.minimum != 0:
            candidates.append(make_axis(axis.kind, minimum=0, maximum=axis.maximum))
            candidates.append(make_axis(axis.kind, minimum=1, maximum=axis.maximum))
        if axis.maximum != 0:
            candidates.append(make_axis(axis.kind, minimum=axis.minimum, maximum=0))
            candidates.append(make_axis(axis.kind, minimum=axis.minimum, maximum=max(1, axis.maximum / 2)))
    candidates.extend([make_axis(0), make_axis(2), make_axis(1, 1), make_axis(3, 0.5)])
    return (candidate for candidate in unique(candidates) if candidate != axis)


def structural_candidates(case: TreeCase) -> Iterable[tuple[str, TreeCase]]:
    for path in sorted(paths(case.root), key=len, reverse=True):
        node = node_at(case.root, path)
        if node.kind != "container":
            continue
        for index, child in enumerate(node.children):
            yield (f"promote child {index} at {path}", case_with_node(case, path, child))
        if len(node.children) > 1:
            for index, child in enumerate(node.children):
                yield (
                    f"keep only child {index} at {path}",
                    case_with_node(case, path, replace(node, children=(child,))),
                )
            for index in range(len(node.children)):
                reduced = (*node.children[:index], *node.children[index + 1 :])
                yield (
                    f"remove child {index} at {path}",
                    case_with_node(case, path, replace(node, children=reduced)),
                )


def config_candidates(config: BoxConfig) -> Iterable[tuple[str, BoxConfig]]:
    scalar_fields = (
        "padding_left",
        "padding_right",
        "padding_top",
        "padding_bottom",
        "gap",
        "align_x",
        "align_y",
        "child_offset_x",
        "child_offset_y",
    )
    if config.direction != 0:
        yield ("direction", replace(config, direction=0))
    for field in scalar_fields:
        value = getattr(config, field)
        for candidate in smaller_numbers(value):
            yield (field, replace(config, **{field: candidate}))
    if config.clip_horizontal:
        yield ("clip_horizontal", replace(config, clip_horizontal=False))
    if config.clip_vertical:
        yield ("clip_vertical", replace(config, clip_vertical=False))
    for candidate in axis_candidates(config.width_sizing):
        yield ("width_sizing", replace(config, width_sizing=candidate))
    for candidate in axis_candidates(config.height_sizing):
        yield ("height_sizing", replace(config, height_sizing=candidate))


def text_line_candidates(lines: tuple[tuple[int, ...], ...]) -> Iterable[tuple[tuple[int, ...], ...]]:
    if len(lines) > 1:
        for index, line in enumerate(lines):
            yield (line,)
            yield (*lines[:index], *lines[index + 1 :])
    for line_index, line in enumerate(lines):
        if len(line) > 1:
            for word_index, word in enumerate(line):
                replacement = list(lines)
                replacement[line_index] = (word,)
                yield tuple(replacement)
                replacement = list(lines)
                replacement[line_index] = (*line[:word_index], *line[word_index + 1 :])
                yield tuple(replacement)
        for word_index, word in enumerate(line):
            for length in smaller_numbers(word, allow_zero=False):
                replacement_line = list(line)
                replacement_line[word_index] = length
                replacement = list(lines)
                replacement[line_index] = tuple(replacement_line)
                yield tuple(replacement)


def local_candidates(case: TreeCase) -> Iterable[tuple[str, TreeCase]]:
    for width in smaller_numbers(case.root_width, allow_zero=False):
        yield (f"root width -> {width}", replace(case, root_width=width))
    for height in smaller_numbers(case.root_height, allow_zero=False):
        yield (f"root height -> {height}", replace(case, root_height=height))

    for path in sorted(paths(case.root), key=len, reverse=True):
        node = node_at(case.root, path)
        if node.aspect is not None:
            yield (f"remove aspect at {path}", case_with_node(case, path, replace(node, aspect=None)))
            for aspect in unique([1.0, 0.5]):
                if aspect != node.aspect and aspect > 0:
                    yield (f"aspect at {path} -> {aspect}", case_with_node(case, path, replace(node, aspect=aspect)))
        for label, config in config_candidates(node.config):
            yield (f"{label} at {path}", case_with_node(case, path, replace(node, config=config)))

        if node.kind == "intrinsic":
            for width in smaller_numbers(node.intrinsic_width):
                yield (f"intrinsic width at {path} -> {width}", case_with_node(case, path, replace(node, intrinsic_width=width)))
            for height in smaller_numbers(node.intrinsic_height):
                yield (f"intrinsic height at {path} -> {height}", case_with_node(case, path, replace(node, intrinsic_height=height)))
        elif node.kind == "text":
            for lines in text_line_candidates(node.text_lines):
                yield (f"simplify text at {path}", case_with_node(case, path, replace(node, text_lines=lines)))
            if node.text_wrap_mode != 0:
                yield (f"wrap mode at {path} -> 0", case_with_node(case, path, replace(node, text_wrap_mode=0)))
            if node.text_align != 0:
                yield (f"text align at {path} -> 0", case_with_node(case, path, replace(node, text_align=0)))
            for size in smaller_numbers(node.font_size, allow_zero=False):
                yield (f"font size at {path} -> {size}", case_with_node(case, path, replace(node, font_size=size)))
            for height in smaller_numbers(node.line_height):
                yield (f"line height at {path} -> {height}", case_with_node(case, path, replace(node, line_height=height)))


class Evaluator:
    def __init__(
        self,
        oracle: Path,
        roc: Path,
        cache_dir: Path,
        output: Path,
        seed: int,
        minimum_delta: float,
        maximum_delta: float,
    ) -> None:
        self.oracle = oracle
        self.roc = roc
        self.cache_dir = cache_dir
        self.output = output
        self.seed = seed
        self.minimum_delta = minimum_delta
        self.maximum_delta = maximum_delta
        self.binary = cache_dir.parent / "build" / f".roclay-tree-reducer-{os.getpid()}"
        self.binary.parent.mkdir(parents=True, exist_ok=True)
        self.cache: dict[str, float] = {}
        self.evaluations = 0

    def source_and_delta(self, case: TreeCase) -> tuple[str, float]:
        wire, names = wire_case(case)
        completed = subprocess.run(
            [str(self.oracle), "--tree-stdin"],
            input=wire + "\n",
            text=True,
            capture_output=True,
            check=True,
        )
        expected = parse_oracle(completed.stdout)
        source = generate_source([case], {case.name: names}, expected, self.seed)
        self.output.write_text(source, encoding="utf-8")
        candidate_source = self.output.with_name(
            f"{self.output.stem}_candidate_{self.evaluations}{self.output.suffix}"
        )
        candidate_source.write_text(source, encoding="utf-8")

        environment = {**os.environ, "ROC_CACHE_DIR": str(self.cache_dir)}
        self.binary.unlink(missing_ok=True)
        try:
            build = subprocess.run(
                [
                    str(self.roc),
                    "build",
                    "--no-cache",
                    "--opt=dev",
                    f"--output={self.binary}",
                    str(candidate_source),
                ],
                text=True,
                capture_output=True,
                env=environment,
                timeout=120,
            )
        finally:
            candidate_source.unlink(missing_ok=True)
        if build.returncode != 0:
            raise RuntimeError(f"Roc failed to build a reduction candidate:\n{build.stdout}{build.stderr}")
        result = subprocess.run(
            [str(self.binary)],
            text=True,
            capture_output=True,
            timeout=120,
        )
        self.binary.unlink(missing_ok=True)
        if result.returncode == 0:
            return wire, 0.0
        diagnostics = result.stdout + result.stderr
        expected_rects: list[tuple[float, float, float, float]] = []
        actual_rects: list[tuple[float, float, float, float]] = []
        for line in diagnostics.splitlines():
            match = RECT_LINE.match(line)
            if match is None:
                continue
            rect = tuple(float(match.group(index)) for index in range(2, 6))
            (expected_rects if match.group(1) == "expected" else actual_rects).append(rect)
        if not expected_rects or not actual_rects:
            raise RuntimeError(f"Roc failed without conformance diagnostics:\n{diagnostics}")
        if len(expected_rects) != len(actual_rects):
            return wire, float("inf")
        delta = max(
            abs(expected_value - actual_value)
            for expected_rect, actual_rect in zip(expected_rects, actual_rects)
            for expected_value, actual_value in zip(expected_rect, actual_rect)
        )
        return wire, delta

    def evaluate(self, case: TreeCase, *, force: bool = False) -> float:
        wire, _names = wire_case(case)
        cache_key = f"root_size {case.root_width} {case.root_height}\n{wire}"
        if not force and cache_key in self.cache:
            return self.cache[cache_key]
        _wire, delta = self.source_and_delta(case)
        self.cache[cache_key] = delta
        self.evaluations += 1
        return delta

    def preserves(self, case: TreeCase) -> tuple[bool, float]:
        delta = self.evaluate(case)
        return self.minimum_delta <= delta <= self.maximum_delta, delta


def reduce_pass(
    case: TreeCase,
    evaluator: Evaluator,
    candidates: Iterable[tuple[str, TreeCase]],
) -> tuple[TreeCase, bool]:
    current_complexity = case_complexity(case)
    for label, candidate in candidates:
        candidate_complexity = case_complexity(candidate)
        if candidate_complexity >= current_complexity:
            continue
        preserves, delta = evaluator.preserves(candidate)
        if preserves:
            print(
                f"accept delta={delta:.4f} nodes={node_count(candidate.root)} "
                f"complexity={candidate_complexity}: {label}",
                flush=True,
            )
            return candidate, True
    return case, False


def load_case(seed: int, case_number: int) -> TreeCase:
    rng = random.Random(seed)
    generated = None
    for index in range(case_number):
        generated = generate_case(rng, index)
    if generated is None:
        raise ValueError("case number must be positive")
    return replace(generated, name="reduced")


def main() -> None:
    parser = argparse.ArgumentParser()
    roc_path = shutil.which(os.environ.get("ROC", "roc"))
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--case", type=int, required=True, help="one-based case number")
    parser.add_argument("--min-delta", type=float, default=0.05)
    parser.add_argument(
        "--max-delta",
        type=float,
        help="reject candidates whose divergence grows into a different failure",
    )
    parser.add_argument("--oracle", type=Path, default=Path("build/clay-oracle"))
    parser.add_argument("--roc", type=Path, default=Path(roc_path) if roc_path else None)
    parser.add_argument("--cache-dir", type=Path, default=Path(".cache/roc"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--corpus-output", type=Path)
    args = parser.parse_args()
    if args.roc is None:
        parser.error("roc executable not found on PATH; pass --roc")

    output = args.output or Path(f"tests/RoclayTreeReduced_{args.seed}_{args.case}.roc")
    corpus_output = args.corpus_output or Path(f"build/roclay-reduced-{args.seed}-{args.case}.txt")
    output.parent.mkdir(parents=True, exist_ok=True)
    corpus_output.parent.mkdir(parents=True, exist_ok=True)

    case = load_case(args.seed, args.case)
    initial_case = case
    initial_evaluator = Evaluator(
        args.oracle.resolve(),
        args.roc.resolve(),
        args.cache_dir.resolve(),
        output.resolve(),
        args.seed,
        args.min_delta,
        float("inf"),
    )
    initial_delta = initial_evaluator.evaluate(initial_case)
    confirmed_delta = initial_evaluator.evaluate(initial_case, force=True)
    if confirmed_delta != initial_delta:
        raise SystemExit(
            f"nondeterministic initial predicate: {initial_delta:.4f} then {confirmed_delta:.4f}"
        )
    if initial_delta < args.min_delta:
        raise SystemExit(
            f"initial case delta {initial_delta:.4f} is below --min-delta {args.min_delta:.4f}"
        )
    maximum_delta = args.max_delta if args.max_delta is not None else initial_delta * 1.25
    if maximum_delta < initial_delta:
        raise SystemExit(
            f"initial case delta {initial_delta:.4f} exceeds --max-delta {maximum_delta:.4f}"
        )
    initial_evaluator.maximum_delta = maximum_delta
    evaluator = initial_evaluator
    print(
        f"start delta={initial_delta:.4f} nodes={node_count(case.root)} "
        f"complexity={case_complexity(case)} band={args.min_delta:.4f}..{maximum_delta:.4f}",
        flush=True,
    )

    while True:
        case, changed = reduce_pass(case, evaluator, structural_candidates(case))
        if changed:
            continue
        case, changed = reduce_pass(case, evaluator, local_candidates(case))
        if not changed:
            break

    wire, delta = evaluator.source_and_delta(case)
    corpus_output.write_text(wire + "\n", encoding="utf-8")
    print(
        f"done delta={delta:.4f} nodes={node_count(case.root)} "
        f"complexity={case_complexity(case)} evaluations={evaluator.evaluations}",
        flush=True,
    )
    print(f"roc={output} corpus={corpus_output}", flush=True)


if __name__ == "__main__":
    main()
