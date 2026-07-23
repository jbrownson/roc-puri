#!/usr/bin/env python3
"""Generate deterministic Roclay flat cases with Clay-derived expectations."""

from __future__ import annotations

import argparse
import random
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class AxisSizing:
    kind: int
    value: float
    minimum: float
    maximum: float
    roc: str


@dataclass(frozen=True)
class Child:
    width: int
    height: int
    width_sizing: AxisSizing
    height_sizing: AxisSizing
    aspect: float | None


@dataclass(frozen=True)
class FlatCase:
    name: str
    direction: int
    padding_left: int
    padding_right: int
    padding_top: int
    padding_bottom: int
    gap: int
    align_x: int
    align_y: int
    root_width: int
    root_height: int
    children: tuple[Child, ...]


def number(value: float | int) -> str:
    if isinstance(value, int):
        return str(value)
    return format(value, ".9g")


def bounds(minimum: float | None, maximum: float | None) -> str:
    min_roc = "Unbounded" if minimum is None else f"Bounded({number(minimum)})"
    max_roc = "Unbounded" if maximum is None else f"Bounded({number(maximum)})"
    return f"{{ min: {min_roc}, max: {max_roc} }}"


def axis_sizing(rng: random.Random) -> AxisSizing:
    choice = rng.randint(0, 9)
    if choice == 0:
        return AxisSizing(0, 0, 0, 0, "Fit(Roclay.unbounded)")
    if choice == 1:
        value = rng.randint(1, 80)
        return AxisSizing(1, value, value, value, f"Fixed({value})")
    if choice == 2:
        return AxisSizing(2, 0, 0, 0, "Fill(Roclay.unbounded)")
    if choice == 3:
        value = rng.randint(1, 100) / 100
        return AxisSizing(3, value, 0, 0, f"Percent({number(value)})")
    if choice in (4, 7):
        maximum = rng.randint(1, 80)
        tag = "Fill" if choice == 4 else "Fit"
        return AxisSizing(2 if choice == 4 else 0, 0, 0, maximum, f"{tag}({bounds(None, maximum)})")
    if choice in (5, 8):
        minimum = rng.randint(1, 40)
        tag = "Fill" if choice == 5 else "Fit"
        return AxisSizing(2 if choice == 5 else 0, 0, minimum, 0, f"{tag}({bounds(minimum, None)})")
    minimum = rng.randint(1, 40)
    maximum = rng.randint(minimum, 80)
    tag = "Fill" if choice == 6 else "Fit"
    return AxisSizing(2 if choice == 6 else 0, 0, minimum, maximum, f"{tag}({bounds(minimum, maximum)})")


def generate_case(rng: random.Random, index: int) -> FlatCase:
    children = []
    for _ in range(rng.randint(1, 4)):
        aspect = None if rng.randint(1, 5) <= 4 else rng.randint(5, 40) / 10
        children.append(
            Child(
                width=rng.randint(1, 80),
                height=rng.randint(1, 60),
                width_sizing=axis_sizing(rng),
                height_sizing=axis_sizing(rng),
                aspect=aspect,
            )
        )
    return FlatCase(
        name=f"flat{index:04d}",
        direction=rng.randint(0, 1),
        padding_left=rng.randint(0, 20),
        padding_right=rng.randint(0, 20),
        padding_top=rng.randint(0, 20),
        padding_bottom=rng.randint(0, 20),
        gap=rng.randint(0, 16),
        align_x=rng.randint(0, 2),
        align_y=rng.randint(0, 2),
        root_width=rng.randint(40, 220),
        root_height=rng.randint(30, 160),
        children=tuple(children),
    )


def wire_line(case: FlatCase) -> str:
    words = [
        case.name,
        str(case.direction),
        str(case.padding_left),
        str(case.padding_right),
        str(case.padding_top),
        str(case.padding_bottom),
        str(case.gap),
        str(case.align_x),
        str(case.align_y),
        str(case.root_width),
        str(case.root_height),
        str(len(case.children)),
    ]
    for child in case.children:
        words.extend(
            [
                str(child.width),
                str(child.height),
                str(child.width_sizing.kind),
                str(child.height_sizing.kind),
                number(child.width_sizing.value),
                number(child.height_sizing.value),
                number(child.width_sizing.minimum),
                number(child.height_sizing.minimum),
                number(child.width_sizing.maximum),
                number(child.height_sizing.maximum),
                "0" if child.aspect is None else number(child.aspect),
            ]
        )
    return " ".join(words)


def roc_align(value: int) -> str:
    return ("AlignStart", "AlignCenter", "AlignEnd")[value]


def roc_child(child: Child) -> str:
    aspect = "None" if child.aspect is None else f"Some({number(child.aspect)})"
    return (
        "{ intrinsic: Geometry2d.size("
        f"{child.width}, {child.height}), sizing: {{ width: {child.width_sizing.roc}, "
        f"height: {child.height_sizing.roc} }}, aspect_ratio: {aspect} }}"
    )


def roc_rect(values: tuple[float, float, float, float]) -> str:
    return "Geometry2d.rect(" + ", ".join(number(value) for value in values) + ")"


def generate_source(
    cases: list[FlatCase],
    expected: dict[str, list[tuple[str, tuple[float, float, float, float]]]],
    seed: int,
) -> str:
    lines = [
        'app [main!] { test_host: platform "../../test-platform/main.roc", geometry: "../../geometry/main.roc", roclay: "../../roclay/main.roc", conformance: "./main.roc" }',
        "",
        "# Generated by tools/generate_flat_conformance.py; do not edit.",
        f"# seed={seed} cases={len(cases)}",
        "import geometry.Geometry2d",
        "import roclay.Roclay",
        "import conformance.RoclayFlatConformance",
        "import test_host.TestDebug",
        "",
        "cases : List(RoclayFlatConformance.FlatCase)",
        "cases = [",
    ]
    child_names = ("a", "b", "c", "d")
    for index, case in enumerate(cases, start=1):
        rows = expected[case.name]
        wanted_names = ["root", *child_names[: len(case.children)]]
        actual_names = [name for name, _rect in rows]
        if actual_names != wanted_names:
            raise RuntimeError(f"unexpected Clay IDs for {case.name}: {actual_names}")
        direction = "LeftToRight" if case.direction == 0 else "TopToBottom"
        children = ", ".join(roc_child(child) for child in case.children)
        rects = ", ".join(roc_rect(rect) for _name, rect in rows)
        lines.extend(
            [
                f"\t# case {index}: {case.name}",
                "\t{",
                f"\t\tdirection: {direction},",
                f"\t\tpadding: Geometry2d.insets({case.padding_top}, {case.padding_right}, {case.padding_bottom}, {case.padding_left}),",
                f"\t\tgap: {case.gap},",
                f"\t\talign_x: {roc_align(case.align_x)},",
                f"\t\talign_y: {roc_align(case.align_y)},",
                f"\t\troot_size: Geometry2d.size({case.root_width}, {case.root_height}),",
                f"\t\tchildren: [{children}],",
                f"\t\texpected: [{rects}],",
                "\t},",
            ]
        )
    lines.extend(
        [
            "]",
            "",
            "run! : List(RoclayFlatConformance.FlatCase) => I32",
            "run! = |all_cases| {",
            "\tvar $failure = 0",
            "\tvar $case_number = 1",
            "\tfor case in all_cases {",
            "\t\tif $failure == 0 and !(RoclayFlatConformance.matches!(case)) {",
            "\t\t\tTestDebug.case!($case_number)",
            "\t\t\tfor rect in case.expected {",
            "\t\t\t\tTestDebug.expected_rect!(rect.x, rect.y, rect.width, rect.height)",
            "\t\t\t}",
            "\t\t\tfor rect in RoclayFlatConformance.actual!(case) {",
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


def parse_oracle(output: str) -> dict[str, list[tuple[str, tuple[float, float, float, float]]]]:
    parsed: dict[str, list[tuple[str, tuple[float, float, float, float]]]] = {}
    for line in output.splitlines():
        case_name, element_id, x, y, width, height = line.split()
        parsed.setdefault(case_name, []).append(
            (element_id, (float(x), float(y), float(width), float(height)))
        )
    return parsed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--oracle", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--corpus-output", type=Path, required=True)
    parser.add_argument("--cases", type=int, default=250)
    parser.add_argument("--seed", type=int, default=0x524F434C4159)
    args = parser.parse_args()

    if args.cases < 1 or args.cases > 10000:
        parser.error("--cases must be between 1 and 10000")

    rng = random.Random(args.seed)
    cases = [generate_case(rng, index) for index in range(args.cases)]
    corpus = "\n".join(wire_line(case) for case in cases) + "\n"
    completed = subprocess.run(
        [str(args.oracle), "--stdin"],
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
    args.output.write_text(generate_source(cases, expected, args.seed), encoding="utf-8")
    args.corpus_output.write_text(corpus, encoding="utf-8")


if __name__ == "__main__":
    main()
