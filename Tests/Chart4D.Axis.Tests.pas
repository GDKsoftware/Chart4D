{*******************************************************}
{                                                       }
{       Chart4D Library - Editorial data charts         }
{                                                       }
{          Copyright(c) 2026 GDK Software               }
{                All rights reserved                    }
{                                                       }
{             Licensed under MIT License                }
{                                                       }
{*******************************************************}
unit Chart4D.Axis.Tests;

/// <summary>
/// Tests for <c>TAxisScale</c>: the "nice numbers" break algorithm, value formatting,
/// and break label building, per SPEC.md section 4.5.
/// </summary>

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Chart4D.Axis,
  Chart4D.Types;

type
  [TestFixture]
  TAxisScaleNiceBreaksTests = class
  private
    procedure AssertBreaksEqual(const Expected, Actual: TArray<Double>);

  public
    [Test]
    procedure NiceBreaks_ZeroToEightyFive_ReturnsSpecExampleBreaks;

    [Test]
    procedure NiceBreaks_YearRange_ReturnsSpecExampleBreaks;

    [Test]
    procedure NiceBreaks_ZeroToOneWithFiveTargetBreaks_ReturnsFractionalBreaks;

    [Test]
    procedure NiceBreaks_DegenerateRange_TreatsRangeAsPlusMinusOne;

    [Test]
    procedure NiceBreaks_NegativeRange_ReturnsBreaksAcrossZero;

    [Test]
    procedure NiceBreaks_LargeRange_ReturnsBillionStepBreaks;

    [Test]
    procedure NiceBreaks_LargeRange_KeepsAllBreaksWithinRange;
  end;

  [TestFixture]
  TAxisScaleFormatValueTests = class
  public
    [Test]
    procedure FormatValue_NoThousandSeparator_UsesInvariantDecimalPoint;

    [Test]
    procedure FormatValue_WithThousandSeparator_UsesCommaGrouping;

    [Test]
    procedure FormatValue_TrailingDecimalZero_IsRemoved;

    [Test]
    procedure FormatValue_NegativeValue_KeepsMinusSign;
  end;

  [TestFixture]
  TAxisScaleBuildLabelsTests = class
  public
    [Test]
    procedure BuildLabels_SuffixOnLastOnly_AppendsToLastBreakOnly;

    [Test]
    procedure BuildLabels_SuffixOnAllBreaks_AppendsToEveryBreak;

    [Test]
    procedure BuildLabels_ManualBreakLabels_WinOverAutomaticFormatting;

    [Test]
    procedure BuildLabels_NoSuffixConfigured_FormatsBreaksPlain;
  end;

  [TestFixture]
  TAxisScaleLocaleFormatValueTests = class
  public
    [Test]
    procedure FormatValue_DutchLocale_UsesCommaDecimalSeparator;

    [Test]
    procedure FormatValue_DutchLocaleWithThousandSeparator_UsesDotGrouping;

    [Test]
    procedure FormatValue_TwoArgumentOverload_StaysInvariantRegardlessOfLocaleOverload;
  end;

  [TestFixture]
  TAxisScaleLogBreaksTests = class
  public
    [Test]
    procedure LogBreaks_FiveToThreeThousand_ReturnsBoundingPowersOfTen;

    [Test]
    procedure LogBreaks_NonPositiveMinValue_RaisesException;

    [Test]
    procedure LogBreaks_LogBaseOne_RaisesException;

    [Test]
    procedure LogBreaks_LogBaseZero_RaisesException;
  end;

  [TestFixture]
  TValueRangeWithOverridesTests = class
  public
    [Test]
    procedure WithOverrides_ManualMinAndMax_ReplacesBothEnds;

    [Test]
    procedure WithOverrides_ReversedManualRange_RaisesException;
  end;

  [TestFixture]
  TAxisScaleDateModeTests = class
  public
    [Test]
    procedure ResolveDateMode_SpanAtSixtyDays_ResolvesToDay;

    [Test]
    procedure ResolveDateMode_SpanJustAboveSixtyDays_ResolvesToMonth;

    [Test]
    procedure ResolveDateMode_SpanAtSevenHundredThirtyDays_ResolvesToMonth;

    [Test]
    procedure ResolveDateMode_SpanJustAboveSevenHundredThirtyDays_ResolvesToQuarter;

    [Test]
    procedure ResolveDateMode_SpanAtTwoThousandNineHundredTwentyDays_ResolvesToQuarter;

    [Test]
    procedure ResolveDateMode_SpanJustAboveTwoThousandNineHundredTwentyDays_ResolvesToYear;

    [Test]
    procedure ResolveDateMode_NonAutoMode_ReturnsModeUnchanged;

    [Test]
    procedure DateBreaks_DayMode_ReturnsBreaksInsideRange;

    [Test]
    procedure DateBreaks_MonthMode_ReturnsBreaksInsideRange;

    [Test]
    procedure DateBreaks_QuarterMode_ReturnsBreaksInsideRange;

    [Test]
    procedure DateBreaks_YearMode_ReturnsBreaksInsideRange;

    [Test]
    procedure DateBreaks_DayModeSubDaySpan_ReturnsNoBreaks;

    [Test]
    procedure DateBreaks_DayModeEmptySpanOnAWholeDay_ReturnsThatSingleDay;

    [Test]
    procedure FormatDateValue_DayMode_FormatsAsDayAndMonth;

    [Test]
    procedure FormatDateValue_MonthMode_FormatsAsMonthAndYear;

    [Test]
    procedure FormatDateValue_QuarterMode_FormatsAsQuarterAndYear;

    [Test]
    procedure FormatDateValue_YearMode_FormatsAsYear;
  end;

implementation

uses
  System.DateUtils;

procedure TAxisScaleNiceBreaksTests.AssertBreaksEqual(const Expected, Actual: TArray<Double>);
begin
  Assert.AreEqual(Length(Expected), Length(Actual), 'Break count mismatch');
  for var Index := 0 to High(Expected) do
  begin
    Assert.AreEqual(Expected[Index], Actual[Index], 1E-9,
      Format('Break at index %d mismatch', [Index]));
  end;
end;

procedure TAxisScaleNiceBreaksTests.NiceBreaks_ZeroToEightyFive_ReturnsSpecExampleBreaks;
begin
  const Expected: TArray<Double> = [0, 20, 40, 60, 80];

  const Actual = TAxisScale.NiceBreaks(0, 85);

  AssertBreaksEqual(Expected, Actual);
end;

procedure TAxisScaleNiceBreaksTests.NiceBreaks_YearRange_ReturnsSpecExampleBreaks;
begin
  const Expected: TArray<Double> = [1960, 1970, 1980, 1990, 2000];

  const Actual = TAxisScale.NiceBreaks(1952, 2007);

  AssertBreaksEqual(Expected, Actual);
end;

procedure TAxisScaleNiceBreaksTests.NiceBreaks_ZeroToOneWithFiveTargetBreaks_ReturnsFractionalBreaks;
begin
  const Expected: TArray<Double> = [0, 0.2, 0.4, 0.6, 0.8, 1.0];

  const Actual = TAxisScale.NiceBreaks(0, 1, 5);

  AssertBreaksEqual(Expected, Actual);
end;

procedure TAxisScaleNiceBreaksTests.NiceBreaks_DegenerateRange_TreatsRangeAsPlusMinusOne;
begin
  const Expected: TArray<Double> = [4, 4.5, 5, 5.5, 6];

  const Actual = TAxisScale.NiceBreaks(5, 5);

  AssertBreaksEqual(Expected, Actual);
end;

procedure TAxisScaleNiceBreaksTests.NiceBreaks_NegativeRange_ReturnsBreaksAcrossZero;
begin
  const Expected: TArray<Double> = [-100, -50, 0, 50, 100];

  const Actual = TAxisScale.NiceBreaks(-100, 100);

  AssertBreaksEqual(Expected, Actual);
end;

procedure TAxisScaleNiceBreaksTests.NiceBreaks_LargeRange_ReturnsBillionStepBreaks;
begin
  const Expected: TArray<Double> = [1E9, 2E9, 3E9, 4E9, 5E9];

  const Actual = TAxisScale.NiceBreaks(5E5, 5E9);

  AssertBreaksEqual(Expected, Actual);
end;

procedure TAxisScaleNiceBreaksTests.NiceBreaks_LargeRange_KeepsAllBreaksWithinRange;
begin
  const MinValue = 1.7E7;
  const MaxValue = 9.3E9;

  const Breaks = TAxisScale.NiceBreaks(MinValue, MaxValue);

  Assert.IsTrue(Length(Breaks) > 0, 'Expected at least one break');
  for var CurrentBreak in Breaks do
  begin
    Assert.IsTrue((CurrentBreak >= MinValue) and (CurrentBreak <= MaxValue),
      Format('Break %g outside [%g, %g]', [CurrentBreak, MinValue, MaxValue]));
  end;
end;

procedure TAxisScaleFormatValueTests.FormatValue_NoThousandSeparator_UsesInvariantDecimalPoint;
begin
  const Expected = '1234.5';

  const Actual = TAxisScale.FormatValue(1234.5, False);

  Assert.AreEqual(Expected, Actual);
end;

procedure TAxisScaleFormatValueTests.FormatValue_WithThousandSeparator_UsesCommaGrouping;
begin
  const Expected = '1,234.5';

  const Actual = TAxisScale.FormatValue(1234.5, True);

  Assert.AreEqual(Expected, Actual);
end;

procedure TAxisScaleFormatValueTests.FormatValue_TrailingDecimalZero_IsRemoved;
begin
  const Expected = '5';

  const Actual = TAxisScale.FormatValue(5.0, False);

  Assert.AreEqual(Expected, Actual);
end;

procedure TAxisScaleFormatValueTests.FormatValue_NegativeValue_KeepsMinusSign;
begin
  const Expected = '-40';

  const Actual = TAxisScale.FormatValue(-40, False);

  Assert.AreEqual(Expected, Actual);
end;

procedure TAxisScaleBuildLabelsTests.BuildLabels_SuffixOnLastOnly_AppendsToLastBreakOnly;
begin
  const Breaks: TArray<Double> = [0, 20, 40];
  var Options := TAxisOptions.Default;
  Options.LabelSuffix := ' years';
  Options.SuffixOnLastOnly := True;

  const Labels = TAxisScale.BuildLabels(Breaks, Options);

  Assert.AreEqual(3, Length(Labels));
  Assert.AreEqual('0', Labels[0]);
  Assert.AreEqual('20', Labels[1]);
  Assert.AreEqual('40 years', Labels[2]);
end;

procedure TAxisScaleBuildLabelsTests.BuildLabels_SuffixOnAllBreaks_AppendsToEveryBreak;
begin
  const Breaks: TArray<Double> = [0, 25, 50];
  var Options := TAxisOptions.Default;
  Options.LabelSuffix := '%';
  Options.SuffixOnLastOnly := False;

  const Labels = TAxisScale.BuildLabels(Breaks, Options);

  Assert.AreEqual(3, Length(Labels));
  Assert.AreEqual('0%', Labels[0]);
  Assert.AreEqual('25%', Labels[1]);
  Assert.AreEqual('50%', Labels[2]);
end;

procedure TAxisScaleBuildLabelsTests.BuildLabels_ManualBreakLabels_WinOverAutomaticFormatting;
begin
  const Breaks: TArray<Double> = [0, 1, 2];
  var Options := TAxisOptions.Default;
  Options.BreakLabels := ['Low', 'Mid', 'High'];
  Options.LabelSuffix := '%';

  const Labels = TAxisScale.BuildLabels(Breaks, Options);

  Assert.AreEqual(3, Length(Labels));
  Assert.AreEqual('Low', Labels[0]);
  Assert.AreEqual('Mid', Labels[1]);
  Assert.AreEqual('High', Labels[2]);
end;

procedure TAxisScaleBuildLabelsTests.BuildLabels_NoSuffixConfigured_FormatsBreaksPlain;
begin
  const Breaks: TArray<Double> = [0, 10.5, 21];
  const Options = TAxisOptions.Default;

  const Labels = TAxisScale.BuildLabels(Breaks, Options);

  Assert.AreEqual(3, Length(Labels));
  Assert.AreEqual('0', Labels[0]);
  Assert.AreEqual('10.5', Labels[1]);
  Assert.AreEqual('21', Labels[2]);
end;

procedure TAxisScaleLocaleFormatValueTests.FormatValue_DutchLocale_UsesCommaDecimalSeparator;
begin
  const Expected = '1234,5';

  const Actual = TAxisScale.FormatValue(1234.5, False, 'nl-NL');

  Assert.AreEqual(Expected, Actual);
end;

procedure TAxisScaleLocaleFormatValueTests.FormatValue_DutchLocaleWithThousandSeparator_UsesDotGrouping;
begin
  const Expected = '1.234,5';

  const Actual = TAxisScale.FormatValue(1234.5, True, 'nl-NL');

  Assert.AreEqual(Expected, Actual);
end;

procedure TAxisScaleLocaleFormatValueTests.FormatValue_TwoArgumentOverload_StaysInvariantRegardlessOfLocaleOverload;
begin
  const Expected = '1234.5';

  const Actual = TAxisScale.FormatValue(1234.5, False);

  Assert.AreEqual(Expected, Actual);
end;

procedure TAxisScaleLogBreaksTests.LogBreaks_FiveToThreeThousand_ReturnsBoundingPowersOfTen;
begin
  const Expected: TArray<Double> = [1, 10, 100, 1000, 10000];

  const Actual = TAxisScale.LogBreaks(5, 3000, 10);

  Assert.AreEqual(Length(Expected), Length(Actual));
  for var Index := 0 to High(Expected) do
  begin
    Assert.AreEqual(Expected[Index], Actual[Index], 1E-9);
  end;
end;

procedure TAxisScaleLogBreaksTests.LogBreaks_NonPositiveMinValue_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TAxisScale.LogBreaks(0, 100, 10);
    end,
    EChart4DException,
    'LogBreaks must raise EChart4DException when MinValue <= 0');
end;

procedure TAxisScaleLogBreaksTests.LogBreaks_LogBaseOne_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TAxisScale.LogBreaks(1, 100, 1);
    end,
    EChart4DException,
    'LogBreaks must raise EChart4DException when LogBase is 1');
end;

procedure TAxisScaleLogBreaksTests.LogBreaks_LogBaseZero_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TAxisScale.LogBreaks(1, 100, 0);
    end,
    EChart4DException,
    'LogBreaks must raise EChart4DException when LogBase is 0');
end;

procedure TValueRangeWithOverridesTests.WithOverrides_ManualMinAndMax_ReplacesBothEnds;
begin
  var Options := TAxisOptions.Default;
  Options.MinValue := 5;
  Options.MaxValue := 50;

  const Overridden = TValueRange.Create(10, 20).WithOverrides(Options);

  Assert.AreEqual<Double>(5, Overridden.Min);
  Assert.AreEqual<Double>(50, Overridden.Max);
end;

procedure TValueRangeWithOverridesTests.WithOverrides_ReversedManualRange_RaisesException;
begin
  var Options := TAxisOptions.Default;
  Options.MinValue := 100;
  Options.MaxValue := 10;

  Assert.WillRaise(
    procedure
    begin
      TValueRange.Create(0, 1).WithOverrides(Options);
    end,
    EChart4DException,
    'WithOverrides must raise EChart4DException when the manual range is reversed');
end;

procedure TAxisScaleDateModeTests.ResolveDateMode_SpanAtSixtyDays_ResolvesToDay;
begin
  const Resolved = TAxisScale.ResolveDateMode(0, 60, TAxisDateMode.Auto);

  Assert.AreEqual(Integer(TAxisDateMode.Day), Integer(Resolved));
end;

procedure TAxisScaleDateModeTests.ResolveDateMode_SpanJustAboveSixtyDays_ResolvesToMonth;
begin
  const Resolved = TAxisScale.ResolveDateMode(0, 61, TAxisDateMode.Auto);

  Assert.AreEqual(Integer(TAxisDateMode.Month), Integer(Resolved));
end;

procedure TAxisScaleDateModeTests.ResolveDateMode_SpanAtSevenHundredThirtyDays_ResolvesToMonth;
begin
  const Resolved = TAxisScale.ResolveDateMode(0, 730, TAxisDateMode.Auto);

  Assert.AreEqual(Integer(TAxisDateMode.Month), Integer(Resolved));
end;

procedure TAxisScaleDateModeTests.ResolveDateMode_SpanJustAboveSevenHundredThirtyDays_ResolvesToQuarter;
begin
  const Resolved = TAxisScale.ResolveDateMode(0, 731, TAxisDateMode.Auto);

  Assert.AreEqual(Integer(TAxisDateMode.Quarter), Integer(Resolved));
end;

procedure TAxisScaleDateModeTests.ResolveDateMode_SpanAtTwoThousandNineHundredTwentyDays_ResolvesToQuarter;
begin
  const Resolved = TAxisScale.ResolveDateMode(0, 2920, TAxisDateMode.Auto);

  Assert.AreEqual(Integer(TAxisDateMode.Quarter), Integer(Resolved));
end;

procedure TAxisScaleDateModeTests.ResolveDateMode_SpanJustAboveTwoThousandNineHundredTwentyDays_ResolvesToYear;
begin
  const Resolved = TAxisScale.ResolveDateMode(0, 2921, TAxisDateMode.Auto);

  Assert.AreEqual(Integer(TAxisDateMode.Year), Integer(Resolved));
end;

procedure TAxisScaleDateModeTests.ResolveDateMode_NonAutoMode_ReturnsModeUnchanged;
begin
  const Resolved = TAxisScale.ResolveDateMode(0, 10000, TAxisDateMode.Day);

  Assert.AreEqual(Integer(TAxisDateMode.Day), Integer(Resolved));
end;

procedure TAxisScaleDateModeTests.DateBreaks_DayMode_ReturnsBreaksInsideRange;
begin
  const MinValue = EncodeDate(2024, 1, 1);
  const MaxValue = MinValue + 10;

  const Breaks = TAxisScale.DateBreaks(MinValue, MaxValue, TAxisDateMode.Day);

  Assert.AreEqual(6, Length(Breaks));
  Assert.AreEqual(MinValue, Breaks[0], 1E-9);
  Assert.AreEqual(MaxValue, Breaks[High(Breaks)], 1E-9);
end;

procedure TAxisScaleDateModeTests.DateBreaks_MonthMode_ReturnsBreaksInsideRange;
begin
  const MinValue = EncodeDate(2024, 1, 1);
  const MaxValue = EncodeDate(2024, 6, 1);

  const Breaks = TAxisScale.DateBreaks(MinValue, MaxValue, TAxisDateMode.Month);

  Assert.AreEqual(6, Length(Breaks));
  Assert.AreEqual(MinValue, Breaks[0], 1E-9);
  Assert.AreEqual(MaxValue, Breaks[High(Breaks)], 1E-9);
end;

procedure TAxisScaleDateModeTests.DateBreaks_QuarterMode_ReturnsBreaksInsideRange;
begin
  const MinValue = EncodeDate(2024, 1, 1);
  const MaxValue = EncodeDate(2025, 1, 1);

  const Breaks = TAxisScale.DateBreaks(MinValue, MaxValue, TAxisDateMode.Quarter);

  Assert.AreEqual(5, Length(Breaks));
  Assert.AreEqual(MinValue, Breaks[0], 1E-9);
  Assert.AreEqual(MaxValue, Breaks[High(Breaks)], 1E-9);
end;

procedure TAxisScaleDateModeTests.DateBreaks_YearMode_ReturnsBreaksInsideRange;
begin
  const MinValue = EncodeDate(2000, 1, 1);
  const MaxValue = EncodeDate(2020, 1, 1);

  const Breaks = TAxisScale.DateBreaks(MinValue, MaxValue, TAxisDateMode.Year);

  Assert.AreEqual(5, Length(Breaks));
  Assert.AreEqual(MinValue, Breaks[0], 1E-9);
  Assert.AreEqual(MaxValue, Breaks[High(Breaks)], 1E-9);
end;

procedure TAxisScaleDateModeTests.DateBreaks_DayModeSubDaySpan_ReturnsNoBreaks;
begin
  { A span that contains no whole-day boundary has no calendar-aligned day to put a break
    on, so the break list is empty rather than an error. }
  const MinValue = EncodeDate(2024, 3, 5) + 0.25;
  const MaxValue = EncodeDate(2024, 3, 5) + 0.75;

  const Breaks = TAxisScale.DateBreaks(MinValue, MaxValue, TAxisDateMode.Day);

  Assert.AreEqual(0, Length(Breaks));
end;

procedure TAxisScaleDateModeTests.DateBreaks_DayModeEmptySpanOnAWholeDay_ReturnsThatSingleDay;
begin
  const DayValue = EncodeDate(2024, 3, 5);

  const Breaks = TAxisScale.DateBreaks(DayValue, DayValue, TAxisDateMode.Day);

  Assert.AreEqual(1, Length(Breaks));
  Assert.AreEqual(DayValue, Breaks[0], 1E-9);
end;

procedure TAxisScaleDateModeTests.FormatDateValue_DayMode_FormatsAsDayAndMonth;
begin
  const Expected = '5 Mar';

  const Actual = TAxisScale.FormatDateValue(EncodeDate(2024, 3, 5), TAxisDateMode.Day);

  Assert.AreEqual(Expected, Actual);
end;

procedure TAxisScaleDateModeTests.FormatDateValue_MonthMode_FormatsAsMonthAndYear;
begin
  const Expected = 'Mar 2024';

  const Actual = TAxisScale.FormatDateValue(EncodeDate(2024, 3, 1), TAxisDateMode.Month);

  Assert.AreEqual(Expected, Actual);
end;

procedure TAxisScaleDateModeTests.FormatDateValue_QuarterMode_FormatsAsQuarterAndYear;
begin
  const Expected = 'Q3 2024';

  const Actual = TAxisScale.FormatDateValue(EncodeDate(2024, 8, 15), TAxisDateMode.Quarter);

  Assert.AreEqual(Expected, Actual);
end;

procedure TAxisScaleDateModeTests.FormatDateValue_YearMode_FormatsAsYear;
begin
  const Expected = '2024';

  const Actual = TAxisScale.FormatDateValue(EncodeDate(2024, 1, 1), TAxisDateMode.Year);

  Assert.AreEqual(Expected, Actual);
end;

end.
