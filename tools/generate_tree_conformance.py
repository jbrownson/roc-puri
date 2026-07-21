#!/usr/bin/env python3
"""Generate deterministic recursive Roclay cases with Clay expectations."""

from __future__ import annotations

import argparse
import random
import subprocess
from dataclasses import dataclass
from pathlib import Path

from generate_flat_conformance import AxisSizing, axis_sizing, number, parse_oracle


@dataclass(frozen=True)
class BoxConfig:
    direction: int
    padding_left: int
    padding_right: int
    padding_top: int
    padding_bottom: int
    gap: int
    align_x: int
    align_y: int
    width_sizing: AxisSizing
    height_sizing: AxisSizing
    clip_horizontal: bool
    clip_vertical: bool
    child_offset_x: int
    child_offset_y: int


@dataclass(frozen=True)
class Node:
    kind: str
    config: BoxConfig
    aspect: float | None
    intrinsic_width: int = 0
    intrinsic_height: int = 0
    children: tuple[Node, ...] = ()
    text_lines: tuple[tuple[int, ...], ...] = ()
    text_wrap_mode: int = 0
    text_align: int = 0
    font_size: int = 1
    line_height: int = 0

    @property
    def text(self) -> str:
        return "\n".join(
            " ".join("x" * length for length in line) for line in self.text_lines
        )


@dataclass(frozen=True)
class TreeCase:
    name: str
    root_width: int
    root_height: int
    root: Node


def fixed_axis(value: int) -> AxisSizing:
    return AxisSizing(1, value, value, value, f"Fixed({value})")


def fit_unbounded() -> AxisSizing:
    return AxisSizing(0, 0, 0, 0, "Fit(Roclay.unbounded)")


def aspect_ratio(rng: random.Random) -> float | None:
    return None if rng.randint(1, 5) <= 4 else rng.randint(5, 40) / 10


def fixed_size(sizing: AxisSizing) -> int | None:
    return int(sizing.value) if sizing.kind == 1 else None


def padding_pair(rng: random.Random, maximum_total: int | None) -> tuple[int, int]:
    if maximum_total is None:
        return (0, 0)
    maximum_total = max(0, maximum_total)
    first = rng.randint(0, min(20, maximum_total))
    second = rng.randint(0, min(20, maximum_total - first))
    return (first, second)


def box_config(
    rng: random.Random,
    child_count: int,
    width_sizing: AxisSizing,
    height_sizing: AxisSizing,
) -> BoxConfig:
    direction = rng.randint(0, 1)
    main_sizing = width_sizing if direction == 0 else height_sizing
    main_fixed = fixed_size(main_sizing)
    if child_count > 1 and main_fixed is not None:
        gap = rng.randint(0, min(16, main_fixed // (child_count - 1)))
    else:
        gap = 0
    horizontal_reserved = gap * (child_count - 1) if direction == 0 else 0
    vertical_reserved = gap * (child_count - 1) if direction == 1 else 0
    width_fixed = fixed_size(width_sizing)
    height_fixed = fixed_size(height_sizing)
    left, right = padding_pair(
        rng,
        None if width_fixed is None else width_fixed - horizontal_reserved,
    )
    top, bottom = padding_pair(
        rng,
        None if height_fixed is None else height_fixed - vertical_reserved,
    )
    return BoxConfig(
        direction=direction,
        padding_left=left,
        padding_right=right,
        padding_top=top,
        padding_bottom=bottom,
        gap=gap,
        align_x=rng.randint(0, 2),
        align_y=rng.randint(0, 2),
        width_sizing=width_sizing,
        height_sizing=height_sizing,
        clip_horizontal=rng.randint(1, 4) == 4,
        clip_vertical=rng.randint(1, 4) == 4,
        child_offset_x=rng.randint(-20, 20),
        child_offset_y=rng.randint(-20, 20),
    )


def leaf_config(width_sizing: AxisSizing, height_sizing: AxisSizing) -> BoxConfig:
    return BoxConfig(
        direction=0,
        padding_left=0,
        padding_right=0,
        padding_top=0,
        padding_bottom=0,
        gap=0,
        align_x=0,
        align_y=0,
        width_sizing=width_sizing,
        height_sizing=height_sizing,
        clip_horizontal=False,
        clip_vertical=False,
        child_offset_x=0,
        child_offset_y=0,
    )


def generate_node(rng: random.Random, depth: int) -> Node:
    make_container = depth > 0 and rng.randint(1, 7) > 3
    if not make_container:
        width_sizing = axis_sizing(rng)
        height_sizing = axis_sizing(rng)
        if rng.randint(0, 1) == 1:
            wrap_mode = rng.randint(0, 2)
            font_size = rng.randint(1, 5)
            line_count = rng.randint(1, 4) if wrap_mode == 1 else 1
            return Node(
                kind="text",
                config=leaf_config(width_sizing, height_sizing),
                aspect=aspect_ratio(rng),
                text_lines=tuple(
                    tuple(rng.randint(1, 20) for _ in range(rng.randint(1, 8)))
                    for _ in range(line_count)
                ),
                text_wrap_mode=wrap_mode,
                text_align=rng.randint(0, 2),
                font_size=font_size,
                line_height=0 if rng.randint(1, 4) <= 3 else rng.randint(1, font_size * 3),
            )
        return Node(
            kind="intrinsic",
            config=leaf_config(width_sizing, height_sizing),
            aspect=aspect_ratio(rng),
            intrinsic_width=rng.randint(1, 80),
            intrinsic_height=rng.randint(1, 60),
        )
    child_count = rng.randint(1, 4)
    width_sizing = axis_sizing(rng)
    height_sizing = axis_sizing(rng)
    return Node(
        kind="container",
        config=box_config(rng, child_count, width_sizing, height_sizing),
        aspect=aspect_ratio(rng),
        children=tuple(generate_node(rng, depth - 1) for _ in range(child_count)),
    )


def generate_case(rng: random.Random, index: int) -> TreeCase:
    root_width = rng.randint(40, 220)
    root_height = rng.randint(30, 160)
    child_count = rng.randint(1, 4)
    root_config = box_config(
        rng,
        child_count,
        fixed_axis(root_width),
        fixed_axis(root_height),
    )
    root = Node(
        kind="container",
        config=root_config,
        aspect=None,
        children=tuple(generate_node(rng, 3) for _ in range(child_count)),
    )
    return TreeCase(f"tree{index:04d}", root_width, root_height, root)


def wire_config(config: BoxConfig) -> list[str]:
    return [
        str(config.direction),
        str(config.padding_left),
        str(config.padding_right),
        str(config.padding_top),
        str(config.padding_bottom),
        str(config.gap),
        str(config.align_x),
        str(config.align_y),
        str(config.width_sizing.kind),
        str(config.height_sizing.kind),
        number(config.width_sizing.value),
        number(config.height_sizing.value),
        number(config.width_sizing.minimum),
        number(config.height_sizing.minimum),
        number(config.width_sizing.maximum),
        number(config.height_sizing.maximum),
    ]


def wire_node(node: Node, name: str, next_index: int) -> tuple[list[str], list[str], int]:
    words = [
        name,
        str(len(node.children)),
        str(node.intrinsic_width),
        str(node.intrinsic_height),
        *wire_config(node.config),
        "0" if node.aspect is None else number(node.aspect),
        {"intrinsic": "0", "text": "1", "container": "2"}[node.kind],
        "1" if node.config.clip_horizontal else "0",
        "1" if node.config.clip_vertical else "0",
        str(node.config.child_offset_x),
        str(node.config.child_offset_y),
    ]
    if node.kind == "text":
        words.extend(
            [
                str(node.text_wrap_mode),
                str(node.text_align),
                str(node.font_size),
                str(node.line_height),
                str(len(node.text_lines)),
            ]
        )
        for line in node.text_lines:
            words.extend([str(len(line)), *(str(length) for length in line)])
    names = [name]
    for child in node.children:
        child_name = f"n{next_index}"
        next_index += 1
        child_words, child_names, next_index = wire_node(child, child_name, next_index)
        words.extend(child_words)
        names.extend(child_names)
    return words, names, next_index


def wire_case(case: TreeCase) -> tuple[str, list[str]]:
    words, names, _next_index = wire_node(case.root, "root", 0)
    return " ".join([case.name, *words]), names


def roc_config(config: BoxConfig) -> str:
    direction = "LeftToRight" if config.direction == 0 else "TopToBottom"
    align_tags = ("Start", "Center", "End")
    if config.direction == 0:
        main_align = "Main" + align_tags[config.align_x]
        cross_align = "Cross" + align_tags[config.align_y]
    else:
        main_align = "Main" + align_tags[config.align_y]
        cross_align = "Cross" + align_tags[config.align_x]
    horizontal = "Bool.True" if config.clip_horizontal else "Bool.False"
    vertical = "Bool.True" if config.clip_vertical else "Bool.False"
    return (
        "{ ..Roclay.default_box, "
        f"direction: {direction}, "
        f"padding: Geometry2d.insets({config.padding_top}, {config.padding_right}, {config.padding_bottom}, {config.padding_left}), "
        f"gap: {config.gap}, "
        f"sizing: {{ width: {config.width_sizing.roc}, height: {config.height_sizing.roc} }}, "
        f"main_align: {main_align}, cross_align: {cross_align}, "
        f"clip: {{ horizontal: {horizontal}, vertical: {vertical}, "
        f"child_offset: Geometry2d.point({config.child_offset_x}, {config.child_offset_y}) }} }}"
    )


def roc_node(node: Node, indent: str) -> list[str]:
    aspect = "None" if node.aspect is None else f"Some({number(node.aspect)})"
    tag = {"intrinsic": "IntrinsicNode", "text": "TextNode", "container": "ContainerNode"}[node.kind]
    lines = [f"{indent}{tag}({{", f"{indent}\tconfig: {roc_config(node.config)},", f"{indent}\taspect_ratio: {aspect},"]
    if node.kind == "intrinsic":
        lines.append(
            f"{indent}\tintrinsic: Geometry2d.size({node.intrinsic_width}, {node.intrinsic_height}),"
        )
    elif node.kind == "text":
        wraps = ("TextWrapWords", "TextWrapNewlines", "TextWrapNone")
        aligns = ("TextAlignStart", "TextAlignCenter", "TextAlignEnd")
        line_height = "None" if node.line_height == 0 else f"Some({node.line_height})"
        text = node.text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        lines.extend(
            [
                f'{indent}\ttext: "{text}",',
                f"{indent}\tfont_size: {node.font_size},",
                f"{indent}\tline_height: {line_height},",
                f"{indent}\twrap_mode: {wraps[node.text_wrap_mode]},",
                f"{indent}\talign: {aligns[node.text_align]},",
            ]
        )
    else:
        lines.append(f"{indent}\tchildren: [")
        for child in node.children:
            child_lines = roc_node(child, indent + "\t\t")
            child_lines[-1] += ","
            lines.extend(child_lines)
        lines.append(f"{indent}\t],")
    lines.append(f"{indent}}})")
    return lines


def roc_rect(values: tuple[float, float, float, float]) -> str:
    return "Geometry2d.rect(" + ", ".join(number(value) for value in values) + ")"


def generate_source(
    cases: list[TreeCase],
    case_names: dict[str, list[str]],
    expected: dict[str, list[tuple[str, tuple[float, float, float, float]]]],
    seed: int,
) -> str:
    lines = [
        'app [main!] { test_host: platform "../test-platform/main.roc" }',
        "",
        "# Generated by tools/generate_tree_conformance.py; do not edit.",
        f"# seed={seed} cases={len(cases)}",
        "import Geometry2d",
        "import Roclay",
        "import RoclayTreeConformance",
        "import test_host.TestDebug",
        "",
        "cases : List(RoclayTreeConformance.TreeCase)",
        "cases = [",
    ]
    for index, case in enumerate(cases, start=1):
        rows = expected[case.name]
        actual_names = [name for name, _rect in rows]
        if actual_names != case_names[case.name]:
            raise RuntimeError(f"unexpected Clay IDs for {case.name}: {actual_names}")
        lines.extend([f"\t# case {index}: {case.name}", "\t{"])
        lines.append(f"\t\troot_size: Geometry2d.size({case.root_width}, {case.root_height}),")
        lines.append("\t\troot:")
        node_lines = roc_node(case.root, "\t\t\t")
        node_lines[-1] += ","
        lines.extend(node_lines)
        rects = ", ".join(roc_rect(rect) for _name, rect in rows)
        lines.extend([f"\t\texpected: [{rects}],", "\t},"])
    lines.extend(
        [
            "]",
            "",
            "run! : List(RoclayTreeConformance.TreeCase) => I32",
            "run! = |all_cases| {",
            "\tvar $failure = 0",
            "\tvar $case_number = 1",
            "\tfor case in all_cases {",
            "\t\tif $failure == 0 and !(RoclayTreeConformance.matches!(case)) {",
            "\t\t\tTestDebug.case!($case_number)",
            "\t\t\tfor rect in case.expected {",
            "\t\t\t\tTestDebug.expected_rect!(rect.x, rect.y, rect.width, rect.height)",
            "\t\t\t}",
            "\t\t\tfor rect in RoclayTreeConformance.actual!(case) {",
            "\t\t\t\tTestDebug.actual_rect!(rect.x, rect.y, rect.width, rect.height)",
            "\t\t\t}",
            "\t\t\t$failure = $case_number",
            "\t\t}",
            "\t\t$case_number = $case_number + 1",
            "\t}",
            "\t$failure",
            "}",
            "",
            "main! = || run!(cases)",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--oracle", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--corpus-output", type=Path, required=True)
    parser.add_argument("--cases", type=int, default=50)
    parser.add_argument("--seed", type=int, default=0x54524545434C4159)
    args = parser.parse_args()

    if args.cases < 1 or args.cases > 1000:
        parser.error("--cases must be between 1 and 1000")

    rng = random.Random(args.seed)
    cases = [generate_case(rng, index) for index in range(args.cases)]
    wired = [wire_case(case) for case in cases]
    corpus = "\n".join(line for line, _names in wired) + "\n"
    names = {case.name: wired[index][1] for index, case in enumerate(cases)}
    completed = subprocess.run(
        [str(args.oracle), "--tree-stdin"],
        input=corpus,
        text=True,
        capture_output=True,
        check=True,
    )
    expected = parse_oracle(completed.stdout)
    missing = [case.name for case in cases if case.name not in expected]
    if missing:
        raise RuntimeError(f"Clay returned no rows for: {missing}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.corpus_output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(generate_source(cases, names, expected, args.seed), encoding="utf-8")
    args.corpus_output.write_text(corpus, encoding="utf-8")


if __name__ == "__main__":
    main()
