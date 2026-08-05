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
unit Chart4D.Axis;

/// <summary>
/// Axis options, the "nice numbers" break/label algorithms, and the linear data-to-pixel
/// mapper shared by every chart kind.
/// </summary>

interface

uses
  System.Math,
  System.SysUtils,
  Chart4D.Types;

type
  /// <summary>
  /// Configuration of a single chart axis: manual or automatic range and breaks, and
  /// label formatting.
  /// </summary>
  TAxisOptions = record
    /// <summary>The manual minimum of the axis range, or <c>NaN</c> for automatic.</summary>
    MinValue: Double;
    /// <summary>The manual maximum of the axis range, or <c>NaN</c> for automatic.</summary>
    MaxValue: Double;
    /// <summary>The manual break values, or empty for automatic (<c>TAxisScale.NiceBreaks</c>).</summary>
    Breaks: TArray<Double>;
    /// <summary>The manual break labels, or empty for automatic (<c>TAxisScale.BuildLabels</c>).</summary>
    BreakLabels: TArray<string>;
    /// <summary>Whether formatted values use a thousand separator.</summary>
    UseThousandSeparator: Boolean;
    /// <summary>A suffix appended to break labels, e.g. '%' or ' years'.</summary>
    LabelSuffix: string;
    /// <summary>Whether <c>LabelSuffix</c> is appended to the last break only, or to every break.</summary>
    SuffixOnLastOnly: Boolean;
    /// <summary>Whether the axis text is drawn.</summary>
    Visible: Boolean;
    /// <summary>The scale the axis maps data through. Default <c>Linear</c>.</summary>
    Scale: TAxisScaleKind;
    /// <summary>The base of a <c>Logarithmic</c> scale. Default 10.</summary>
    LogBase: Double;
    /// <summary>The calendar granularity of a continuous X axis. Default <c>None</c>.</summary>
    DateMode: TAxisDateMode;
    /// <summary>The locale used to format values, or '' for the invariant convention.</summary>
    LocaleName: string;

    /// <summary>
    /// Returns the default axis options: automatic range and breaks, no thousand
    /// separator, no suffix, visible text, linear scale, no date mode, invariant
    /// formatting.
    /// </summary>
    class function Default: TAxisOptions; static;

    /// <summary>Whether <c>Scale</c> is <c>Logarithmic</c>.</summary>
    function IsLogarithmic: Boolean;
    /// <summary>Whether <c>DateMode</c> is anything other than <c>None</c>.</summary>
    function IsDateAxis: Boolean;
    /// <summary>Whether <c>Breaks</c> holds manually supplied break values.</summary>
    function HasManualBreaks: Boolean;
    /// <summary>Whether <c>BreakLabels</c> holds manually supplied labels.</summary>
    function HasManualLabels: Boolean;
  end;

  /// <summary>
  /// A closed interval of data values, and the rules every axis applies to one: growing
  /// it to cover a set of values, replacing its ends with the axis' manual overrides, and
  /// opening it up when it collapsed to a single value.
  /// </summary>
  TValueRange = record
    /// <summary>The lower bound of the interval.</summary>
    Min: Double;
    /// <summary>The upper bound of the interval.</summary>
    Max: Double;

    /// <summary>Returns the interval <c>[Min, Max]</c>.</summary>
    class function Create(const Min, Max: Double): TValueRange; static;

    /// <summary>
    /// Returns the inverted-infinite interval that covers nothing, so that extending it
    /// with the first value yields exactly that value on both ends.
    /// </summary>
    class function Empty: TValueRange; static;

    /// <summary>Grows the interval so it covers <c>Value</c>.</summary>
    procedure Extend(const Value: Double); overload;
    /// <summary>Grows the interval so it covers every element of <c>Values</c>.</summary>
    procedure Extend(const Values: TArray<Double>); overload;

    /// <summary>The span from <c>Min</c> to <c>Max</c>.</summary>
    function Span: Double;

    /// <summary>
    /// Returns the interval with <c>Options.MinValue</c> and <c>Options.MaxValue</c>
    /// substituted for the matching end wherever they are not <c>NaN</c>. Raises
    /// <c>EChart4DException</c> when the resulting interval is reversed.
    /// </summary>
    function WithOverrides(const Options: TAxisOptions): TValueRange;

    /// <summary>
    /// Returns the interval widened by one unit on each side when both ends are the same
    /// value, and unchanged otherwise. A collapsed interval has no scale to map through,
    /// so every axis opens it up the same way before mapping or picking breaks.
    /// </summary>
    function ExpandedIfDegenerate: TValueRange;
  end;

  /// <summary>
  /// Computes "nice" axis breaks, formats axis values, and builds axis break labels.
  /// </summary>
  TAxisScale = class
  private
    class function NiceStep(const MinValue, MaxValue: Double; const TargetCount: Integer): Double; static;
    class function NiceStepFromRaw(const RawStep: Double): Double; static;
    class function NiceFactor(const Normalized: Double): Double; static;
    class function CollectBreaks(const MinValue, MaxValue, Step: Double): TArray<Double>; static;

    class function FormatValueWithSettings(const Value: Double; const UseThousandSeparator: Boolean;
                                           const Settings: TFormatSettings): string; static;
    class function FormatBreakValue(const Value: Double; const Options: TAxisOptions): string; static;
    class function BuildDateLabels(const Breaks: TArray<Double>; const Options: TAxisOptions): TArray<string>; static;

    class procedure ValidatePositiveLogValue(const Value: Double); static;
    class function DayBreaks(const MinValue, MaxValue: Double): TArray<Double>; static;
    class function MonthBreaks(const MinValue, MaxValue: Double): TArray<Double>; static;
    class function QuarterBreaks(const MinValue, MaxValue: Double): TArray<Double>; static;
    class function YearBreaks(const MinValue, MaxValue: Double): TArray<Double>; static;
    class function SmallestCandidateAtLeast(const Candidates: TArray<Integer>; const Target: Double): Integer; static;

  public
    /// <summary>
    /// Computes evenly spaced "nice" break values inside <c>[MinValue, MaxValue]</c>,
    /// aiming for approximately <c>TargetCount</c> breaks.
    /// </summary>
    class function NiceBreaks(const MinValue, MaxValue: Double;
                              const TargetCount: Integer = 5): TArray<Double>; static;

    /// <summary>
    /// Formats a value using an invariant decimal point, an optional thousand
    /// separator, and no trailing decimal zeros.
    /// </summary>
    class function FormatValue(const Value: Double;
                               const UseThousandSeparator: Boolean): string; overload; static;

    /// <summary>
    /// Formats a value exactly like the 2-argument overload, except through
    /// <c>TFormatSettings.Create(LocaleName)</c> instead of the invariant convention, so
    /// the decimal point, thousand separator and trimmed trailing zeros follow that
    /// locale's own rules.
    /// </summary>
    class function FormatValue(const Value: Double; const UseThousandSeparator: Boolean;
                               const LocaleName: string): string; overload; static;

    /// <summary>
    /// Builds one label per break. <c>Options.BreakLabels</c> wins entirely when
    /// non-empty; otherwise, when <c>Options.DateMode &lt;&gt; TAxisDateMode.None</c>,
    /// every break is formatted with <c>FormatDateValue</c> using <c>Options.DateMode</c>
    /// as it is, which must therefore already be resolved (never <c>Auto</c>); otherwise every break is
    /// formatted with <c>FormatValue</c> (the locale overload when
    /// <c>Options.LocaleName &lt;&gt; ''</c>) and <c>Options.LabelSuffix</c> is appended
    /// per <c>Options.SuffixOnLastOnly</c>.
    /// </summary>
    class function BuildLabels(const Breaks: TArray<Double>;
                               const Options: TAxisOptions): TArray<string>; static;

    /// <summary>
    /// Returns <c>Power(LogBase, Exponent)</c> for every integer exponent from
    /// <c>Floor(LogN(LogBase, MinValue))</c> to <c>Ceil(LogN(LogBase, MaxValue))</c>
    /// inclusive. Raises <c>EChart4DException</c> when <c>LogBase &lt;= 1</c> or
    /// <c>MinValue &lt;= 0</c>.
    /// </summary>
    class function LogBreaks(const MinValue, MaxValue: Double;
                             const LogBase: Double = 10): TArray<Double>; static;

    /// <summary>
    /// Returns <c>Mode</c> unchanged unless it is <c>Auto</c>, in which case it picks a
    /// concrete mode from the span between <c>MinValue</c> and <c>MaxValue</c> in days.
    /// </summary>
    class function ResolveDateMode(const MinValue, MaxValue: Double;
                                   const Mode: TAxisDateMode): TAxisDateMode; static;

    /// <summary>
    /// Returns calendar-aligned breaks inside <c>[MinValue, MaxValue]</c> for the given,
    /// already-resolved <c>Mode</c> (never <c>Auto</c>).
    /// </summary>
    class function DateBreaks(const MinValue, MaxValue: Double;
                              const Mode: TAxisDateMode): TArray<Double>; static;

    /// <summary>
    /// Formats <c>Value</c> for the given, already-resolved <c>Mode</c> (never
    /// <c>Auto</c>), using the invariant convention when <c>LocaleName = ''</c>.
    /// </summary>
    class function FormatDateValue(const Value: Double; const Mode: TAxisDateMode;
                                   const LocaleName: string = ''): string; static;
  end;

  /// <summary>
  /// A linear mapping from a data value range to a pixel coordinate range, optionally
  /// inverted for screen Y coordinates.
  /// </summary>
  TLinearMapper = record
    /// <summary>The lower bound of the data range.</summary>
    DataMin: Double;
    /// <summary>The upper bound of the data range.</summary>
    DataMax: Double;
    /// <summary>The pixel coordinate that <c>DataMin</c> maps to when not inverted.</summary>
    PixelMin: Single;
    /// <summary>The pixel coordinate that <c>DataMax</c> maps to when not inverted.</summary>
    PixelMax: Single;
    /// <summary>When <c>True</c>, the pixel range is swapped (<c>DataMin</c> maps to <c>PixelMax</c>).</summary>
    Inverted: Boolean;

    /// <summary>
    /// Creates a mapper from <c>[DataMin, DataMax]</c> to <c>[PixelMin, PixelMax]</c>.
    /// </summary>
    class function Create(const DataMin, DataMax: Double;
                          const PixelMin, PixelMax: Single;
                          const Inverted: Boolean): TLinearMapper; static;

    /// <summary>
    /// Maps <c>Value</c> from the data range to the pixel range.
    /// </summary>
    function Map(const Value: Double): Single;
  end;

implementation

uses
  System.DateUtils,
  Chart4D.Consts;

class function TAxisOptions.Default: TAxisOptions;
begin
  Result.MinValue := NaN;
  Result.MaxValue := NaN;
  Result.Breaks := [];
  Result.BreakLabels := [];
  Result.UseThousandSeparator := False;
  Result.LabelSuffix := '';
  Result.SuffixOnLastOnly := True;
  Result.Visible := True;
  Result.Scale := TAxisScaleKind.Linear;
  Result.LogBase := 10;
  Result.DateMode := TAxisDateMode.None;
  Result.LocaleName := '';
end;

function TAxisOptions.IsLogarithmic: Boolean;
begin
  Result := (Scale = TAxisScaleKind.Logarithmic);
end;

function TAxisOptions.IsDateAxis: Boolean;
begin
  Result := (DateMode <> TAxisDateMode.None);
end;

function TAxisOptions.HasManualBreaks: Boolean;
begin
  Result := (Length(Breaks) > 0);
end;

function TAxisOptions.HasManualLabels: Boolean;
begin
  Result := (Length(BreakLabels) > 0);
end;

class function TValueRange.Create(const Min, Max: Double): TValueRange;
begin
  Result.Min := Min;
  Result.Max := Max;
end;

class function TValueRange.Empty: TValueRange;
begin
  Result := TValueRange.Create(Infinity, NegInfinity);
end;

procedure TValueRange.Extend(const Value: Double);
begin
  Min := System.Math.Min(Min, Value);
  Max := System.Math.Max(Max, Value);
end;

procedure TValueRange.Extend(const Values: TArray<Double>);
begin
  for var Value in Values do
  begin
    Extend(Value);
  end;
end;

function TValueRange.Span: Double;
begin
  Result := Max - Min;
end;

function TValueRange.WithOverrides(const Options: TAxisOptions): TValueRange;
begin
  Result := Self;
  if not IsNaN(Options.MinValue) then
    Result.Min := Options.MinValue;
  if not IsNaN(Options.MaxValue) then
    Result.Max := Options.MaxValue;

  const IsReversed = (Result.Min > Result.Max);
  if IsReversed then
    raise EChart4DException.CreateFmt(SReversedAxisRange, [Result.Min, Result.Max]);
end;

function TValueRange.ExpandedIfDegenerate: TValueRange;
begin
  Result := Self;

  const IsDegenerate = SameValue(Min, Max);
  if IsDegenerate then
  begin
    Result.Min := Min - 1;
    Result.Max := Max + 1;
  end;
end;

class function TAxisScale.NiceFactor(const Normalized: Double): Double;
begin
  if Normalized < 1.5 then
    Result := 1
  else if Normalized < 3 then
    Result := 2
  else if Normalized < 7 then
    Result := 5
  else
    Result := 10;
end;

class function TAxisScale.NiceStepFromRaw(const RawStep: Double): Double;
begin
  const Magnitude = Power(10, Floor(Log10(RawStep)));
  const Normalized = RawStep / Magnitude;
  Result := NiceFactor(Normalized) * Magnitude;
end;

class function TAxisScale.NiceStep(const MinValue, MaxValue: Double; const TargetCount: Integer): Double;
begin
  const RawStep = (MaxValue - MinValue) / (TargetCount - 1);
  Result := NiceStepFromRaw(RawStep);
end;

class function TAxisScale.CollectBreaks(const MinValue, MaxValue, Step: Double): TArray<Double>;
begin
  const Epsilon = 1E-9;
  const FirstBreak = Ceil(MinValue / Step - Epsilon) * Step;
  const LastBreak = Floor(MaxValue / Step + Epsilon) * Step;
  const BreakCount = Round((LastBreak - FirstBreak) / Step) + 1;

  SetLength(Result, Max(BreakCount, 0));
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := FirstBreak + Index * Step;
  end;
end;

class function TAxisScale.NiceBreaks(const MinValue, MaxValue: Double;
                                     const TargetCount: Integer = 5): TArray<Double>;
begin
  const Range = TValueRange.Create(MinValue, MaxValue).ExpandedIfDegenerate;

  const Step = NiceStep(Range.Min, Range.Max, TargetCount);
  Result := CollectBreaks(Range.Min, Range.Max, Step);
end;

class function TAxisScale.FormatValueWithSettings(const Value: Double; const UseThousandSeparator: Boolean;
                                                  const Settings: TFormatSettings): string;
begin
  var Pattern := '0.##########';
  if UseThousandSeparator then
    Pattern := '#,##0.##########';

  Result := FormatFloat(Pattern, Value, Settings);
end;

class function TAxisScale.FormatValue(const Value: Double;
                                      const UseThousandSeparator: Boolean): string;
begin
  Result := FormatValueWithSettings(Value, UseThousandSeparator, TFormatSettings.Invariant);
end;

class function TAxisScale.FormatValue(const Value: Double; const UseThousandSeparator: Boolean;
                                      const LocaleName: string): string;
begin
  Result := FormatValueWithSettings(Value, UseThousandSeparator, TFormatSettings.Create(LocaleName));
end;

class function TAxisScale.FormatBreakValue(const Value: Double; const Options: TAxisOptions): string;
begin
  if Options.LocaleName <> '' then
    Result := FormatValue(Value, Options.UseThousandSeparator, Options.LocaleName)
  else
    Result := FormatValue(Value, Options.UseThousandSeparator);
end;

class function TAxisScale.BuildDateLabels(const Breaks: TArray<Double>; const Options: TAxisOptions): TArray<string>;
begin
  SetLength(Result, Length(Breaks));
  for var Index := 0 to High(Breaks) do
  begin
    Result[Index] := FormatDateValue(Breaks[Index], Options.DateMode, Options.LocaleName);
  end;
end;

class function TAxisScale.BuildLabels(const Breaks: TArray<Double>;
                                      const Options: TAxisOptions): TArray<string>;
begin
  if Options.HasManualLabels then
    Exit(Options.BreakLabels);

  const IsDateAxis = Options.IsDateAxis and (Length(Breaks) > 0);
  if IsDateAxis then
    Exit(BuildDateLabels(Breaks, Options));

  SetLength(Result, Length(Breaks));
  for var Index := 0 to High(Breaks) do
  begin
    var BreakLabel := FormatBreakValue(Breaks[Index], Options);

    const IsLastBreak = (Index = High(Breaks));
    const AppendSuffix = (Options.LabelSuffix <> '') and (not Options.SuffixOnLastOnly or IsLastBreak);
    if AppendSuffix then
      BreakLabel := BreakLabel + Options.LabelSuffix;

    Result[Index] := BreakLabel;
  end;
end;

class procedure TAxisScale.ValidatePositiveLogValue(const Value: Double);
begin
  if Value <= 0 then
    raise EChart4DException.CreateFmt(SLogAxisRequiresPositiveValues, [Value]);
end;

class function TAxisScale.LogBreaks(const MinValue, MaxValue: Double;
                                    const LogBase: Double = 10): TArray<Double>;
begin
  const HasInvalidLogBase = (LogBase <= 1);
  if HasInvalidLogBase then
    raise EChart4DException.CreateFmt(SLogBaseMustExceedOne, [LogBase]);

  ValidatePositiveLogValue(MinValue);

  const Epsilon = 1E-9;
  const MinExponent: Integer = Floor(LogN(LogBase, MinValue) + Epsilon);
  const MaxExponent: Integer = Ceil(LogN(LogBase, MaxValue) - Epsilon);

  SetLength(Result, MaxExponent - MinExponent + 1);
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := Power(LogBase, MinExponent + Index);
  end;
end;

class function TAxisScale.ResolveDateMode(const MinValue, MaxValue: Double;
                                          const Mode: TAxisDateMode): TAxisDateMode;
begin
  if Mode <> TAxisDateMode.Auto then
    Exit(Mode);

  const SpanDays = MaxValue - MinValue;
  if SpanDays <= 60 then
    Result := TAxisDateMode.Day
  else if SpanDays <= 730 then
    Result := TAxisDateMode.Month
  else if SpanDays <= 2920 then
    Result := TAxisDateMode.Quarter
  else
    Result := TAxisDateMode.Year;
end;

class function TAxisScale.SmallestCandidateAtLeast(const Candidates: TArray<Integer>; const Target: Double): Integer;
begin
  Result := Candidates[High(Candidates)];
  for var Candidate in Candidates do
  begin
    if Candidate >= Target then
      Exit(Candidate);
  end;
end;

class function TAxisScale.DayBreaks(const MinValue, MaxValue: Double): TArray<Double>;
begin
  const Candidates: TArray<Integer> = [1, 2, 5, 7, 14, 30];
  const SpanDays = MaxValue - MinValue;
  const StepDays = SmallestCandidateAtLeast(Candidates, SpanDays / 5);

  Result := [];
  var CurrentDay := Ceil(MinValue);
  while CurrentDay <= MaxValue do
  begin
    Result := Result + [Double(CurrentDay)];
    CurrentDay := CurrentDay + StepDays;
  end;
end;

class function TAxisScale.MonthBreaks(const MinValue, MaxValue: Double): TArray<Double>;
begin
  const Candidates: TArray<Integer> = [1, 2, 3, 6, 12];
  const SpanMonths = MonthsBetween(MaxValue, MinValue);
  const StepMonths = SmallestCandidateAtLeast(Candidates, SpanMonths / 5);

  var FirstMonthStart := EncodeDate(YearOf(MinValue), MonthOf(MinValue), 1);
  const IsBeforeMinValue = (FirstMonthStart < MinValue);
  if IsBeforeMinValue then
    FirstMonthStart := IncMonth(FirstMonthStart, 1);

  Result := [];
  var CurrentMonth := FirstMonthStart;
  while CurrentMonth <= MaxValue do
  begin
    Result := Result + [CurrentMonth];
    CurrentMonth := IncMonth(CurrentMonth, StepMonths);
  end;
end;

class function TAxisScale.QuarterBreaks(const MinValue, MaxValue: Double): TArray<Double>;
begin
  const Candidates: TArray<Integer> = [1, 2, 4, 8];
  const SpanQuarters = MonthsBetween(MaxValue, MinValue) / 3;
  const StepQuarters = SmallestCandidateAtLeast(Candidates, SpanQuarters / 5);

  const FirstQuarterMonth = ((MonthOf(MinValue) - 1) div 3) * 3 + 1;
  var FirstQuarterStart := EncodeDate(YearOf(MinValue), FirstQuarterMonth, 1);
  const IsBeforeMinValue = (FirstQuarterStart < MinValue);
  if IsBeforeMinValue then
    FirstQuarterStart := IncMonth(FirstQuarterStart, 3);

  Result := [];
  var CurrentQuarter := FirstQuarterStart;
  while CurrentQuarter <= MaxValue do
  begin
    Result := Result + [CurrentQuarter];
    CurrentQuarter := IncMonth(CurrentQuarter, 3 * StepQuarters);
  end;
end;

class function TAxisScale.YearBreaks(const MinValue, MaxValue: Double): TArray<Double>;
begin
  const RawStep = YearsBetween(MaxValue, MinValue) / 4;
  var StepYears := 1;
  if RawStep >= 1 then
    StepYears := Round(NiceStepFromRaw(RawStep));

  var FirstYear := YearOf(MinValue);
  var FirstYearStart := EncodeDate(FirstYear, 1, 1);
  const IsBeforeMinValue = (FirstYearStart < MinValue);
  if IsBeforeMinValue then
  begin
    Inc(FirstYear);
    FirstYearStart := EncodeDate(FirstYear, 1, 1);
  end;

  Result := [];
  var CurrentYear := FirstYear;
  var CurrentYearStart := FirstYearStart;
  while CurrentYearStart <= MaxValue do
  begin
    Result := Result + [CurrentYearStart];
    CurrentYear := CurrentYear + StepYears;
    CurrentYearStart := EncodeDate(CurrentYear, 1, 1);
  end;
end;

class function TAxisScale.DateBreaks(const MinValue, MaxValue: Double;
                                     const Mode: TAxisDateMode): TArray<Double>;
begin
  case Mode of
    TAxisDateMode.Day     : Result := DayBreaks(MinValue, MaxValue);
    TAxisDateMode.Month   : Result := MonthBreaks(MinValue, MaxValue);
    TAxisDateMode.Quarter : Result := QuarterBreaks(MinValue, MaxValue);
    TAxisDateMode.Year    : Result := YearBreaks(MinValue, MaxValue);
  else
    raise ENotSupportedException.CreateFmt('DateBreaks requires a resolved date mode, got %d', [Ord(Mode)]);
  end;
end;

class function TAxisScale.FormatDateValue(const Value: Double; const Mode: TAxisDateMode;
                                          const LocaleName: string = ''): string;
begin
  var Settings := TFormatSettings.Invariant;
  if LocaleName <> '' then
    Settings := TFormatSettings.Create(LocaleName);

  case Mode of
    TAxisDateMode.Day     : Result := FormatDateTime('d MMM', Value, Settings);
    TAxisDateMode.Month   : Result := FormatDateTime('MMM yyyy', Value, Settings);
    TAxisDateMode.Quarter : Result := Format('Q%d %d', [(MonthOf(Value) - 1) div 3 + 1, YearOf(Value)]);
    TAxisDateMode.Year    : Result := FormatDateTime('yyyy', Value, Settings);
  else
    raise ENotSupportedException.CreateFmt('FormatDateValue requires a resolved date mode, got %d', [Ord(Mode)]);
  end;
end;

class function TLinearMapper.Create(const DataMin, DataMax: Double;
                                    const PixelMin, PixelMax: Single;
                                    const Inverted: Boolean): TLinearMapper;
begin
  Result.DataMin := DataMin;
  Result.DataMax := DataMax;
  Result.PixelMin := PixelMin;
  Result.PixelMax := PixelMax;
  Result.Inverted := Inverted;
end;

function TLinearMapper.Map(const Value: Double): Single;
begin
  const HasZeroDataRange = SameValue(DataMax, DataMin);
  var Ratio: Double := 0;
  if not HasZeroDataRange then
    Ratio := (Value - DataMin) / (DataMax - DataMin);

  var RangeStart := PixelMin;
  var RangeEnd := PixelMax;
  if Inverted then
  begin
    RangeStart := PixelMax;
    RangeEnd := PixelMin;
  end;

  Result := RangeStart + Ratio * (RangeEnd - RangeStart);
end;

end.
