"""Segment and span validation — every slope rule from the spec.

Each validator iterates over candles in a segment and checks whether
HIGH or LOW prices respect the appropriate slope boundary.  Every
single bar check emits a :class:`DiagnosticRecord` BEFORE returning
pass/fail — this is the engine's core explainability contract.

Rule numbering follows ``PXABCDEF_Slope_Conditions_Complete.md``:
  - Case 1 (X<A): rules 1.1–1.17
  - Case 2 (X>A): rules 2.1–2.17

Operator conventions (from the spec):
  - **Strict** (red): ``>``, ``<``, ``>=``, ``<=`` — no buffer
  - **Buffer** (blue): slope ± buffer — ``slope_buffer_pct`` applied
"""

from __future__ import annotations

from typing import List, Callable

from .diagnostics import DiagnosticLog


# ---------------------------------------------------------------------------
# Type alias for the candle-price accessor
# ---------------------------------------------------------------------------
# ``PriceFn(bar_idx) -> float``  — returns iHigh or iLow for that bar.
PriceFn = Callable[[int], float]


# ---------------------------------------------------------------------------
# XB segment (rules 1.2 / 2.2) — STRICT, no buffer
# ---------------------------------------------------------------------------

def validate_xb_segment(
    x_idx: int,
    b_idx: int,
    x_price: float,
    xb_slope: float,
    check_lows: bool,
    price_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Validate candles between X and B against the XB slope line.

    Rules:
      - 1.2 (X<A, check_lows=True): all LOWs > XB slope (strict ``<=`` fails)
      - 2.2 (X>A, check_lows=False): all HIGHs < XB slope (strict ``>=`` fails)
    """
    rule_id = "1.2" if check_lows else "2.2"
    rule_name = "XB strict support" if check_lows else "XB strict resistance"
    op = "<=" if check_lows else ">="

    for i in range(x_idx - 1, b_idx, -1):
        xb_value = x_price + (x_idx - i) * xb_slope
        price = price_fn(i)

        if check_lows:
            passed = price > xb_value  # LOW must be strictly above XB
        else:
            passed = price < xb_value  # HIGH must be strictly below XB

        diag.record(
            rule_id=rule_id, rule_name=rule_name, segment="X→B",
            bar_idx=i, passed=passed, check_type="strict",
            price_checked=price, threshold=xb_value,
            operator=op,
            details=f"{'LOW' if check_lows else 'HIGH'}={price:.5f} vs XB={xb_value:.5f}",
        )
        if not passed:
            return False
    return True


# ---------------------------------------------------------------------------
# PX segment (rules 1.1 / 2.1) — STRICT
# ---------------------------------------------------------------------------

def validate_px_segment(
    p_idx: int,
    x_idx: int,
    p_price: float,
    xb_slope: float,
    check_lows: bool,
    price_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Validate candles between P and X against the PX slope line.

    Rules:
      - 1.1 (X<A): all LOWs >= PX slope (``<`` fails)
      - 2.1 (X>A): all HIGHs <= PX slope (``>`` fails)
    """
    rule_id = "1.1" if check_lows else "2.1"
    rule_name = "PX strict support" if check_lows else "PX strict resistance"
    op = "<" if check_lows else ">"

    for i in range(p_idx, x_idx, -1):
        px_value = p_price + (p_idx - i) * xb_slope
        price = price_fn(i)

        if check_lows:
            passed = price >= px_value
        else:
            passed = price <= px_value

        diag.record(
            rule_id=rule_id, rule_name=rule_name, segment="P→X",
            bar_idx=i, passed=passed, check_type="strict",
            price_checked=price, threshold=px_value, operator=op,
            details=f"{'LOW' if check_lows else 'HIGH'}={price:.5f} vs PX={px_value:.5f}",
        )
        if not passed:
            return False
    return True


# ---------------------------------------------------------------------------
# AB segment (rule 1.3 / 2.3) — BUFFER on AC proxy slope
# ---------------------------------------------------------------------------

def validate_ab_segment(
    a_idx: int,
    b_idx: int,
    a_price: float,
    ac_proxy_slope: float,
    x_less_than_a: bool,
    slope_buffer_pct: float,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Validate A→B candles against the AC proxy slope with buffer.

    Rules:
      - 1.3 (X<A): HIGHs <= AC slope + buffer
      - 2.3 (X>A): LOWs >= AC slope - buffer
    """
    rule_id = "1.3" if x_less_than_a else "2.3"
    rule_name = "AB AC-proxy buffer" if x_less_than_a else "AB AC-proxy buffer"

    for i in range(a_idx - 1, b_idx, -1):
        ac_val = a_price + (a_idx - i) * ac_proxy_slope
        buf = abs(ac_val) * slope_buffer_pct / 100.0

        if x_less_than_a:
            price = high_fn(i)
            threshold = ac_val + buf
            passed = price <= threshold
            op = ">"
        else:
            price = low_fn(i)
            threshold = ac_val - buf
            passed = price >= threshold
            op = "<"

        diag.record(
            rule_id=rule_id, rule_name=rule_name, segment="A→B",
            bar_idx=i, passed=passed, check_type="buffer",
            price_checked=price, threshold=threshold,
            operator=op, buffer_value=buf,
            details=f"{'HIGH' if x_less_than_a else 'LOW'}={price:.5f} vs AC{'+'if x_less_than_a else '-'}buf={threshold:.5f}",
        )
        if not passed:
            return False
    return True


# ---------------------------------------------------------------------------
# Fix 1: A→B re-validation with real AC slope (after C found)
# ---------------------------------------------------------------------------

def validate_ab_with_real_ac(
    a_idx: int,
    b_idx: int,
    a_price: float,
    ac_slope: float,
    x_less_than_a: bool,
    slope_buffer_pct: float,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Fix 1: re-validate A→B with the REAL A→C slope (not proxy).

    Same rules as ``validate_ab_segment`` but with exact slope.
    """
    rule_id = "Fix1"
    rule_name = "AB re-validation (real AC slope)"

    for i in range(a_idx - 1, b_idx, -1):
        ac_val = a_price + (a_idx - i) * ac_slope
        buf = abs(ac_val) * slope_buffer_pct / 100.0

        if x_less_than_a:
            price = high_fn(i)
            threshold = ac_val + buf
            passed = price <= threshold
        else:
            price = low_fn(i)
            threshold = ac_val - buf
            passed = price >= threshold

        diag.record(
            rule_id=rule_id, rule_name=rule_name, segment="A→B (Fix1)",
            bar_idx=i, passed=passed, check_type="buffer",
            price_checked=price, threshold=threshold,
            buffer_value=buf,
            details=f"Re-check {'HIGH' if x_less_than_a else 'LOW'}={price:.5f} vs real AC±buf={threshold:.5f}",
        )
        if not passed:
            return False
    return True


# ---------------------------------------------------------------------------
# BC segment (rules 1.4+1.5 / 2.4+2.5)
# ---------------------------------------------------------------------------

def validate_bc_segment(
    b_idx: int,
    c_idx: int,
    x_price: float,
    x_idx: int,
    a_price: float,
    a_idx: int,
    xb_slope: float,
    ac_slope: float,
    x_less_than_a: bool,
    slope_buffer_pct: float,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Validate B→C segment — XB ext strict + AC slope buffer.

    Rules for X<A:
      - 1.4: LOWs >= XB ext (strict, ``<`` fails)
      - 1.5: HIGHs <= AC slope + buffer
    Rules for X>A:
      - 2.4: HIGHs <= XB ext (strict, ``>`` fails)
      - 2.5: LOWs >= AC slope - buffer
    """
    for i in range(b_idx - 1, c_idx, -1):
        xb_ext = x_price + (x_idx - i) * xb_slope
        ac_val = a_price + (a_idx - i) * ac_slope
        buf = abs(ac_val) * slope_buffer_pct / 100.0

        low = low_fn(i)
        high = high_fn(i)

        if x_less_than_a:
            # Rule 1.4: LOWs >= XB ext (strict)
            passed_xb = low >= xb_ext
            diag.record(
                rule_id="1.4", rule_name="BC XB-ext strict support",
                segment="B→C", bar_idx=i, passed=passed_xb,
                check_type="strict", price_checked=low, threshold=xb_ext,
                operator="<",
                details=f"LOW={low:.5f} vs XB_ext={xb_ext:.5f}",
            )
            if not passed_xb:
                return False

            # Rule 1.5: HIGHs <= AC + buffer
            threshold = ac_val + buf
            passed_ac = high <= threshold
            diag.record(
                rule_id="1.5", rule_name="BC AC buffer resistance",
                segment="B→C", bar_idx=i, passed=passed_ac,
                check_type="buffer", price_checked=high, threshold=threshold,
                buffer_value=buf, operator=">",
                details=f"HIGH={high:.5f} vs AC+buf={threshold:.5f}",
            )
            if not passed_ac:
                return False
        else:
            # Rule 2.4: HIGHs <= XB ext (strict)
            passed_xb = high <= xb_ext
            diag.record(
                rule_id="2.4", rule_name="BC XB-ext strict resistance",
                segment="B→C", bar_idx=i, passed=passed_xb,
                check_type="strict", price_checked=high, threshold=xb_ext,
                operator=">",
                details=f"HIGH={high:.5f} vs XB_ext={xb_ext:.5f}",
            )
            if not passed_xb:
                return False

            # Rule 2.5: LOWs >= AC - buffer
            threshold = ac_val - buf
            passed_ac = low >= threshold
            diag.record(
                rule_id="2.5", rule_name="BC AC buffer support",
                segment="B→C", bar_idx=i, passed=passed_ac,
                check_type="buffer", price_checked=low, threshold=threshold,
                buffer_value=buf, operator="<",
                details=f"LOW={low:.5f} vs AC-buf={threshold:.5f}",
            )
            if not passed_ac:
                return False
    return True


# ---------------------------------------------------------------------------
# Fix 2: B→C re-validation with BD slope (after D found)
# ---------------------------------------------------------------------------

def validate_bc_with_bd(
    b_idx: int,
    c_idx: int,
    b_price: float,
    bd_slope: float,
    x_less_than_a: bool,
    slope_buffer_pct: float,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Fix 2: re-validate B→C candles against BD slope with buffer."""
    rule_id = "Fix2"
    rule_name = "BC re-validation (BD slope)"

    for i in range(b_idx - 1, c_idx, -1):
        bd_val = b_price + (b_idx - i) * bd_slope
        buf = abs(bd_val) * slope_buffer_pct / 100.0

        if x_less_than_a:
            price = low_fn(i)
            threshold = bd_val - buf
            passed = price >= threshold
        else:
            price = high_fn(i)
            threshold = bd_val + buf
            passed = price <= threshold

        diag.record(
            rule_id=rule_id, rule_name=rule_name, segment="B→C (Fix2)",
            bar_idx=i, passed=passed, check_type="buffer",
            price_checked=price, threshold=threshold, buffer_value=buf,
            details=f"Re-check {'LOW' if x_less_than_a else 'HIGH'}={price:.5f} vs BD±buf={threshold:.5f}",
        )
        if not passed:
            return False
    return True


# ---------------------------------------------------------------------------
# CD segment (rules 1.6+1.7 / 2.6+2.7)
# ---------------------------------------------------------------------------

def validate_cd_segment(
    c_idx: int,
    d_idx: int,
    a_price: float,
    a_idx: int,
    b_price: float,
    b_idx: int,
    ac_slope: float,
    bd_slope: float,
    x_less_than_a: bool,
    slope_buffer_pct: float,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Validate C→D segment — AC ext strict + BD slope buffer.

    Rules for X<A:
      - 1.6: HIGHs < AC ext (strict, ``>=`` fails)
      - 1.7: LOWs >= BD - buffer
    Rules for X>A:
      - 2.6: LOWs > AC ext (strict, ``<=`` fails)
      - 2.7: HIGHs <= BD + buffer
    """
    for i in range(c_idx - 1, d_idx, -1):
        ac_ext = a_price + (a_idx - i) * ac_slope
        bd_val = b_price + (b_idx - i) * bd_slope
        buf = abs(bd_val) * slope_buffer_pct / 100.0

        low = low_fn(i)
        high = high_fn(i)

        if x_less_than_a:
            # 1.6: HIGHs < AC ext (strict)
            passed_ac = high < ac_ext
            diag.record(
                rule_id="1.6", rule_name="CD AC-ext strict resistance",
                segment="C→D", bar_idx=i, passed=passed_ac,
                check_type="strict", price_checked=high, threshold=ac_ext,
                operator=">=",
                details=f"HIGH={high:.5f} vs AC_ext={ac_ext:.5f}",
            )
            if not passed_ac:
                return False

            # 1.7: LOWs >= BD - buffer
            threshold = bd_val - buf
            passed_bd = low >= threshold
            diag.record(
                rule_id="1.7", rule_name="CD BD buffer support",
                segment="C→D", bar_idx=i, passed=passed_bd,
                check_type="buffer", price_checked=low, threshold=threshold,
                buffer_value=buf, operator="<",
                details=f"LOW={low:.5f} vs BD-buf={threshold:.5f}",
            )
            if not passed_bd:
                return False
        else:
            # 2.6: LOWs > AC ext (strict)
            passed_ac = low > ac_ext
            diag.record(
                rule_id="2.6", rule_name="CD AC-ext strict support",
                segment="C→D", bar_idx=i, passed=passed_ac,
                check_type="strict", price_checked=low, threshold=ac_ext,
                operator="<=",
                details=f"LOW={low:.5f} vs AC_ext={ac_ext:.5f}",
            )
            if not passed_ac:
                return False

            # 2.7: HIGHs <= BD + buffer
            threshold = bd_val + buf
            passed_bd = high <= threshold
            diag.record(
                rule_id="2.7", rule_name="CD BD buffer resistance",
                segment="C→D", bar_idx=i, passed=passed_bd,
                check_type="buffer", price_checked=high, threshold=threshold,
                buffer_value=buf, operator=">",
                details=f"HIGH={high:.5f} vs BD+buf={threshold:.5f}",
            )
            if not passed_bd:
                return False
    return True


# ---------------------------------------------------------------------------
# Fix 3: C→D re-validation with CE slope (after E found)
# ---------------------------------------------------------------------------

def validate_cd_with_ce(
    c_idx: int,
    d_idx: int,
    c_price: float,
    ce_slope: float,
    x_less_than_a: bool,
    slope_buffer_pct: float,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Fix 3: re-validate C→D candles against CE slope with buffer."""
    rule_id = "Fix3"
    rule_name = "CD re-validation (CE slope)"

    for i in range(c_idx - 1, d_idx, -1):
        ce_val = c_price + (c_idx - i) * ce_slope
        buf = abs(ce_val) * slope_buffer_pct / 100.0

        if x_less_than_a:
            price = high_fn(i)
            threshold = ce_val + buf
            passed = price <= threshold
        else:
            price = low_fn(i)
            threshold = ce_val - buf
            passed = price >= threshold

        diag.record(
            rule_id=rule_id, rule_name=rule_name, segment="C→D (Fix3)",
            bar_idx=i, passed=passed, check_type="buffer",
            price_checked=price, threshold=threshold, buffer_value=buf,
            details=f"Re-check {'HIGH' if x_less_than_a else 'LOW'}={price:.5f} vs CE±buf={threshold:.5f}",
        )
        if not passed:
            return False
    return True


# ---------------------------------------------------------------------------
# DE segment (rules 1.8+1.9 / 2.8+2.9)
# ---------------------------------------------------------------------------

def validate_de_segment(
    d_idx: int,
    e_idx: int,
    b_price: float,
    b_idx: int,
    c_price: float,
    c_idx: int,
    bd_slope: float,
    ce_slope: float,
    x_less_than_a: bool,
    slope_buffer_pct: float,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Validate D→E segment — BD ext strict + CE slope buffer.

    Rules for X<A:
      - 1.8: LOWs > BD ext (strict, ``<=`` fails)
      - 1.9: HIGHs <= CE + buffer
    Rules for X>A:
      - 2.8: HIGHs < BD ext (strict, ``>=`` fails)
      - 2.9: LOWs >= CE - buffer
    """
    for i in range(d_idx - 1, e_idx, -1):
        bd_ext = b_price + (b_idx - i) * bd_slope
        ce_val = c_price + (c_idx - i) * ce_slope
        buf = abs(ce_val) * slope_buffer_pct / 100.0

        low = low_fn(i)
        high = high_fn(i)

        if x_less_than_a:
            # 1.8: LOWs > BD ext (strict)
            passed_bd = low > bd_ext
            diag.record(
                rule_id="1.8", rule_name="DE BD-ext strict support",
                segment="D→E", bar_idx=i, passed=passed_bd,
                check_type="strict", price_checked=low, threshold=bd_ext,
                operator="<=",
                details=f"LOW={low:.5f} vs BD_ext={bd_ext:.5f}",
            )
            if not passed_bd:
                return False

            # 1.9: HIGHs <= CE + buffer
            threshold = ce_val + buf
            passed_ce = high <= threshold
            diag.record(
                rule_id="1.9", rule_name="DE CE buffer resistance",
                segment="D→E", bar_idx=i, passed=passed_ce,
                check_type="buffer", price_checked=high, threshold=threshold,
                buffer_value=buf, operator=">",
                details=f"HIGH={high:.5f} vs CE+buf={threshold:.5f}",
            )
            if not passed_ce:
                return False
        else:
            # 2.8: HIGHs < BD ext (strict)
            passed_bd = high < bd_ext
            diag.record(
                rule_id="2.8", rule_name="DE BD-ext strict resistance",
                segment="D→E", bar_idx=i, passed=passed_bd,
                check_type="strict", price_checked=high, threshold=bd_ext,
                operator=">=",
                details=f"HIGH={high:.5f} vs BD_ext={bd_ext:.5f}",
            )
            if not passed_bd:
                return False

            # 2.9: LOWs >= CE - buffer
            threshold = ce_val - buf
            passed_ce = low >= threshold
            diag.record(
                rule_id="2.9", rule_name="DE CE buffer support",
                segment="D→E", bar_idx=i, passed=passed_ce,
                check_type="buffer", price_checked=low, threshold=threshold,
                buffer_value=buf, operator="<",
                details=f"LOW={low:.5f} vs CE-buf={threshold:.5f}",
            )
            if not passed_ce:
                return False
    return True


# ---------------------------------------------------------------------------
# Fix 4: D→E re-validation with DF slope (after F found)
# ---------------------------------------------------------------------------

def validate_de_with_df(
    d_idx: int,
    e_idx: int,
    d_price: float,
    df_slope: float,
    x_less_than_a: bool,
    slope_buffer_pct: float,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Fix 4: re-validate D→E candles against DF slope with buffer."""
    rule_id = "Fix4"
    rule_name = "DE re-validation (DF slope)"

    for i in range(d_idx - 1, e_idx, -1):
        df_val = d_price + (d_idx - i) * df_slope
        buf = abs(df_val) * slope_buffer_pct / 100.0

        if x_less_than_a:
            price = low_fn(i)
            threshold = df_val - buf
            passed = price >= threshold
        else:
            price = high_fn(i)
            threshold = df_val + buf
            passed = price <= threshold

        diag.record(
            rule_id=rule_id, rule_name=rule_name, segment="D→E (Fix4)",
            bar_idx=i, passed=passed, check_type="buffer",
            price_checked=price, threshold=threshold, buffer_value=buf,
            details=f"Re-check {'LOW' if x_less_than_a else 'HIGH'}={price:.5f} vs DF±buf={threshold:.5f}",
        )
        if not passed:
            return False
    return True


# ---------------------------------------------------------------------------
# EF segment (rules 1.10+1.11 / 2.10+2.11)
# ---------------------------------------------------------------------------

def validate_ef_segment(
    e_idx: int,
    f_idx: int,
    c_price: float,
    c_idx: int,
    d_price: float,
    d_idx: int,
    ce_slope: float,
    df_slope: float,
    x_less_than_a: bool,
    slope_buffer_pct: float,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Validate E→F segment — CE ext strict + DF slope buffer.

    Rules for X<A:
      - 1.10: HIGHs < CE ext (strict, ``>=`` fails)
      - 1.11: LOWs >= DF - buffer
    Rules for X>A:
      - 2.10: LOWs > CE ext (strict, ``<=`` fails)
      - 2.11: HIGHs <= DF + buffer
    """
    for i in range(e_idx - 1, f_idx, -1):
        ce_ext = c_price + (c_idx - i) * ce_slope
        df_val = d_price + (d_idx - i) * df_slope
        buf = abs(df_val) * slope_buffer_pct / 100.0

        low = low_fn(i)
        high = high_fn(i)

        if x_less_than_a:
            # 1.10: HIGHs < CE ext (strict)
            passed_ce = high < ce_ext
            diag.record(
                rule_id="1.10", rule_name="EF CE-ext strict resistance",
                segment="E→F", bar_idx=i, passed=passed_ce,
                check_type="strict", price_checked=high, threshold=ce_ext,
                operator=">=",
                details=f"HIGH={high:.5f} vs CE_ext={ce_ext:.5f}",
            )
            if not passed_ce:
                return False

            # 1.11: LOWs >= DF - buffer
            threshold = df_val - buf
            passed_df = low >= threshold
            diag.record(
                rule_id="1.11", rule_name="EF DF buffer support",
                segment="E→F", bar_idx=i, passed=passed_df,
                check_type="buffer", price_checked=low, threshold=threshold,
                buffer_value=buf, operator="<",
                details=f"LOW={low:.5f} vs DF-buf={threshold:.5f}",
            )
            if not passed_df:
                return False
        else:
            # 2.10: LOWs > CE ext (strict)
            passed_ce = low > ce_ext
            diag.record(
                rule_id="2.10", rule_name="EF CE-ext strict support",
                segment="E→F", bar_idx=i, passed=passed_ce,
                check_type="strict", price_checked=low, threshold=ce_ext,
                operator="<=",
                details=f"LOW={low:.5f} vs CE_ext={ce_ext:.5f}",
            )
            if not passed_ce:
                return False

            # 2.11: HIGHs <= DF + buffer
            threshold = df_val + buf
            passed_df = high <= threshold
            diag.record(
                rule_id="2.11", rule_name="EF DF buffer resistance",
                segment="E→F", bar_idx=i, passed=passed_df,
                check_type="buffer", price_checked=high, threshold=threshold,
                buffer_value=buf, operator=">",
                details=f"HIGH={high:.5f} vs DF+buf={threshold:.5f}",
            )
            if not passed_df:
                return False
    return True


# ---------------------------------------------------------------------------
# Span containment (rules 1.13–1.17 / 2.13–2.17)
# ---------------------------------------------------------------------------

def validate_span_containment(
    point1_idx: int,
    point1_price: float,
    point2_idx: int,
    point2_price: float,
    check_upper: bool,
    slope_buffer_pct: float,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
    rule_id: str = "",
    span_label: str = "",
) -> bool:
    """Check ALL candles between two same-side points against their slope.

    Args:
        check_upper: True → check HIGHs <= slope + buffer.
                     False → check LOWs >= slope - buffer.
    """
    bars = point1_idx - point2_idx
    if bars <= 0:
        return True

    slope = (point2_price - point1_price) / bars

    for i in range(point1_idx - 1, point2_idx, -1):
        slope_val = point1_price + (point1_idx - i) * slope
        buf = abs(slope_val) * slope_buffer_pct / 100.0

        if check_upper:
            price = high_fn(i)
            threshold = slope_val + buf
            passed = price <= threshold
        else:
            price = low_fn(i)
            threshold = slope_val - buf
            passed = price >= threshold

        diag.record(
            rule_id=rule_id or ("span_upper" if check_upper else "span_lower"),
            rule_name=f"{span_label} span containment",
            segment=span_label or "span",
            bar_idx=i, passed=passed,
            check_type="buffer",
            price_checked=price, threshold=threshold,
            buffer_value=buf,
            details=f"{'HIGH' if check_upper else 'LOW'}={price:.5f} vs span{'+'if check_upper else '-'}buf={threshold:.5f}",
        )
        if not passed:
            return False
    return True
