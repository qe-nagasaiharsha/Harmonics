"""Diagnostic-first architecture: every validation emits a structured record.

The diagnostic log IS the product. The engine is useless without
explainability — every single pass/fail decision is captured here with
the exact prices, thresholds, and rule references that determined the
outcome.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional


@dataclass(frozen=True, slots=True)
class DiagnosticRecord:
    """One atomic validation check result.

    Attributes:
        rule_id: Spec rule reference, e.g. ``"1.2"``, ``"2.3"``, ``"Fix1"``,
                 ``"1.14/2.14"`` for span containment.
        rule_name: Human-readable name, e.g. ``"XB strict support"``.
        segment: Which segment was checked, e.g. ``"X→B"``, ``"A→C span"``.
        bar_idx: The bar index that was tested.
        passed: Whether this individual check passed.
        check_type: ``"strict"`` (red line) or ``"buffer"`` (blue line).
        price_checked: The actual candle price (HIGH or LOW) that was tested.
        threshold: The slope/channel value it was compared against.
        operator: The comparison operator used, e.g. ``">"``, ``"<="``.
        buffer_value: The buffer amount added/subtracted (0.0 for strict).
        details: Free-text explanation for the dashboard tooltip.
    """
    rule_id: str
    rule_name: str
    segment: str
    bar_idx: int
    passed: bool
    check_type: str  # "strict" | "buffer"
    price_checked: float
    threshold: float
    operator: str = ""
    buffer_value: float = 0.0
    details: str = ""


class DiagnosticLog:
    """Accumulator for diagnostic records within a single detection attempt.

    The log is carried through every validation call so that even failed
    patterns produce a complete diagnostic trail.
    """

    def __init__(self) -> None:
        self._records: List[DiagnosticRecord] = []

    # -- Recording --

    def record(
        self,
        rule_id: str,
        rule_name: str,
        segment: str,
        bar_idx: int,
        passed: bool,
        check_type: str,
        price_checked: float,
        threshold: float,
        operator: str = "",
        buffer_value: float = 0.0,
        details: str = "",
    ) -> None:
        """Append a diagnostic record."""
        self._records.append(DiagnosticRecord(
            rule_id=rule_id,
            rule_name=rule_name,
            segment=segment,
            bar_idx=bar_idx,
            passed=passed,
            check_type=check_type,
            price_checked=price_checked,
            threshold=threshold,
            operator=operator,
            buffer_value=buffer_value,
            details=details,
        ))

    def record_pass(
        self,
        rule_id: str,
        rule_name: str,
        segment: str,
        bar_idx: int,
        check_type: str,
        price_checked: float,
        threshold: float,
        operator: str = "",
        buffer_value: float = 0.0,
        details: str = "",
    ) -> None:
        """Convenience: append a PASSING record."""
        self.record(
            rule_id=rule_id, rule_name=rule_name, segment=segment,
            bar_idx=bar_idx, passed=True, check_type=check_type,
            price_checked=price_checked, threshold=threshold,
            operator=operator, buffer_value=buffer_value, details=details,
        )

    def record_fail(
        self,
        rule_id: str,
        rule_name: str,
        segment: str,
        bar_idx: int,
        check_type: str,
        price_checked: float,
        threshold: float,
        operator: str = "",
        buffer_value: float = 0.0,
        details: str = "",
    ) -> None:
        """Convenience: append a FAILING record."""
        self.record(
            rule_id=rule_id, rule_name=rule_name, segment=segment,
            bar_idx=bar_idx, passed=False, check_type=check_type,
            price_checked=price_checked, threshold=threshold,
            operator=operator, buffer_value=buffer_value, details=details,
        )

    # -- Querying --

    @property
    def records(self) -> List[DiagnosticRecord]:
        return list(self._records)

    @property
    def failures(self) -> List[DiagnosticRecord]:
        return [r for r in self._records if not r.passed]

    @property
    def all_passed(self) -> bool:
        return all(r.passed for r in self._records)

    def for_segment(self, segment: str) -> List[DiagnosticRecord]:
        return [r for r in self._records if r.segment == segment]

    def for_bar(self, bar_idx: int) -> List[DiagnosticRecord]:
        return [r for r in self._records if r.bar_idx == bar_idx]

    def for_rule(self, rule_id: str) -> List[DiagnosticRecord]:
        return [r for r in self._records if r.rule_id == rule_id]

    def snapshot(self) -> List[DiagnosticRecord]:
        """Return an immutable copy of all records accumulated so far."""
        return list(self._records)

    def clear(self) -> None:
        self._records.clear()

    def __len__(self) -> int:
        return len(self._records)

    def __repr__(self) -> str:
        n_pass = sum(1 for r in self._records if r.passed)
        n_fail = len(self._records) - n_pass
        return f"DiagnosticLog({n_pass} passed, {n_fail} failed)"
