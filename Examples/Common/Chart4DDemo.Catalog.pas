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
unit Chart4DDemo.Catalog;

/// <summary>
/// The shared catalogue behind both demos and the gallery tool: every example, with the
/// code that produces it and an explanation of when to reach for it. The VCL and the FMX
/// demo differ only in the controls they use to show a chart, so keeping the examples
/// here means a change lands everywhere at once, and the code fragment on screen cannot
/// drift away from the chart next to it, because the same record carries both.
///
/// Every <c>Code</c> fragment is complete: it declares the data it uses, so it can be
/// copied into a project and compiled as it stands, against a <c>TChartPlot</c> named
/// <c>Plot</c>. The declaration lines, and the title, subtitle and source assignments, are
/// generated from the values a sample passes to its <c>Sample</c> call rather than typed
/// into the fragment by hand, so the heading shown next to a chart can never drift from
/// the one the chart actually draws; only the body, the remaining calls that build the
/// chart, is hand-written.
///
/// This unit is framework independent: it uses the Chart4D core only, never VCL or FMX.
///
/// All figures are published World Bank World Development Indicators data, except the
/// electricity mix, which is Ember data via Our World in Data, and the temperature
/// anomaly, which is HadCRUT5 from the Met Office Hadley Centre. Values are rounded to one
/// decimal, except the temperature anomaly and its interval, which are rounded to two
/// because the whole series spans little more than one degree. The ten-country set is, in
/// this order: Netherlands, Belgium, France, Germany, Italy, Poland, Portugal, Romania,
/// Spain, Sweden.
/// </summary>

interface

uses
  Chart4D.Plot;

type
  /// <summary>Fills a plot with one example's data and settings.</summary>
  TDemoBuildProc = reference to procedure(const Plot: TChartPlot);

  /// <summary>
  /// One catalogue entry: what to call it, what it teaches, the code that produces it,
  /// and the procedure that actually produces it.
  /// </summary>
  TDemoSample = record
    /// <summary>Short label for a list or combo box.</summary>
    Name: string;
    /// <summary>What this chart is for, and what to look at in it.</summary>
    Explanation: string;
    /// <summary>Complete, compilable Chart4D code that produces this chart.</summary>
    Code: string;
    /// <summary>Applies the example to a plot.</summary>
    Build: TDemoBuildProc;
  end;

  /// <summary>Static provider of every demo example.</summary>
  TDemoCatalog = class
  private
    class function Lines(const Values: array of string): string; static;
    class function DeclareStringArray(const VarName: string;
                                      const Values: TArray<string>): TArray<string>; static;
    class function DeclareDoubleArray(const VarName: string; const Values: TArray<Double>;
                                      const Decimals: Integer): TArray<string>; static;
    class function DeclareAssignment(const PropertyName, Value: string): TArray<string>; static;
    class function AssembleCode(const Title, Subtitle, Source: string;
                                const ConstDeclarations: TArray<string>;
                                const Body: array of string): string; static;
    class function Sample(const Name, Explanation, Title, Subtitle: string;
                          const ConstDeclarations: TArray<string>; const Body: array of string;
                          const Build: TDemoBuildProc): TDemoSample; overload; static;
    class function Sample(const Name, Explanation, Title, Subtitle, Source: string;
                          const ConstDeclarations: TArray<string>; const Body: array of string;
                          const Build: TDemoBuildProc): TDemoSample; overload; static;
  public
    /// <summary>Every example, in the order the demos present them.</summary>
    class function Samples: TArray<TDemoSample>; static;
    /// <summary>The source line every example uses unless it states its own.</summary>
    class function DefaultSource: string; static;
  end;

implementation

uses
  System.SysUtils,
  System.UITypes,
  Chart4D.Axis,
  Chart4D.Style,
  Chart4D.Types;

const
  WorldBankSource = 'Source: World Bank';
  EmberSource = 'Source: Ember, via Our World in Data';
  HadCrutSource = 'Source: Met Office Hadley Centre, HadCRUT5';

  TenCountries: TArray<string> = ['Netherlands', 'Belgium', 'France', 'Germany', 'Italy',
                                  'Poland', 'Portugal', 'Romania', 'Spain', 'Sweden'];

  { Life expectancy at birth (SP.DYN.LE00.IN), every five years, 1960 to 2020. }
  DenseYears: TArray<Double> = [1960, 1965, 1970, 1975, 1980, 1985, 1990, 1995, 2000, 2005, 2010, 2015, 2020];
  DenseDutch: TArray<Double> = [73.4, 73.6, 73.6, 74.5, 75.7, 76.3, 76.9, 77.4, 78.0, 79.3, 80.7, 81.5, 81.4];
  DenseFrench: TArray<Double> = [69.9, 70.8, 71.7, 72.9, 74.1, 75.3, 76.6, 77.8, 79.1, 80.2, 81.7, 82.3, 82.2];
  DensePolish: TArray<Double> = [67.7, 69.4, 69.9, 70.6, 70.1, 70.5, 70.9, 71.9, 73.7, 75.0, 76.2, 77.5, 76.4];

  { Global mean surface temperature anomaly against the 1961-1990 average, in degrees
    Celsius, with the 95 per cent confidence interval the analysis publishes for every
    reading. The interval is the point of this example: it is wide while the observing
    network is sparse and narrows as coverage improves, so it is genuine uncertainty
    around a central estimate rather than a spread between two known groups. }
  AnomalyYears: TArray<Double> = [1860, 1880, 1900, 1920, 1940, 1960, 1980, 2000, 2020];
  AnomalyBest: TArray<Double> = [-0.41, -0.30, -0.23, -0.30, 0.07, -0.11, 0.19, 0.33, 0.92];
  AnomalyLow: TArray<Double> = [-0.56, -0.43, -0.36, -0.43, -0.04, -0.17, 0.16, 0.29, 0.88];
  AnomalyHigh: TArray<Double> = [-0.26, -0.18, -0.10, -0.17, 0.19, -0.06, 0.22, 0.36, 0.95];

  { Individuals using the internet, percentage of population (IT.NET.USER.ZS). }
  InternetYears: TArray<Double> = [1990, 1995, 2000, 2005, 2010, 2015, 2020];
  InternetDutch: TArray<Double> = [0.3, 6.5, 44.0, 81.0, 90.7, 91.7, 91.3];
  InternetBelgian: TArray<Double> = [0.0, 1.0, 29.4, 55.8, 77.6, 85.1, 91.5];
  InternetGerman: TArray<Double> = [0.1, 1.8, 30.2, 68.7, 82.0, 87.6, 89.8];
  InternetPolish: TArray<Double> = [0.0, 0.6, 7.3, 38.8, 62.3, 68.0, 83.2];
  InternetRomanian: TArray<Double> = [0.0, 0.1, 3.6, 21.5, 39.9, 55.8, 78.5];

  { CO2 emissions per capita in tonnes (EN.GHG.CO2.PC.CE.AR5), ten countries. }
  Emissions1990: TArray<Double> = [11.0, 11.6, 6.6, 12.7, 7.5, 9.7, 4.4, 8.1, 5.9, 6.7];
  Emissions2020: TArray<Double> = [8.2, 8.0, 4.2, 7.7, 5.0, 7.9, 3.9, 3.9, 4.5, 3.7];

  { Life expectancy in 2020, ten countries, and the same set by sex. }
  RankedCountries: TArray<string> = ['Sweden', 'France', 'Italy', 'Spain', 'Netherlands',
                                     'Portugal', 'Germany', 'Belgium', 'Poland', 'Romania'];
  RankedValues: TArray<Double> = [82.4, 82.2, 82.2, 82.2, 81.4, 81.3, 81.0, 80.7, 76.4, 74.3];

  { Individuals using the internet in 2020, percentage of population, sorted. A quantity
    with a meaningful zero, which is what a bar chart needs. }
  OnlineCountries: TArray<string> = ['Sweden', 'Spain', 'Belgium', 'Netherlands', 'Germany',
                                     'France', 'Poland', 'Romania', 'Portugal', 'Italy'];
  OnlineShare2020: TArray<Double> = [94.5, 93.2, 91.5, 91.3, 89.8, 84.7, 83.2, 78.5, 78.3, 70.5];
  MaleValues: TArray<Double> = [79.7, 78.5, 79.2, 78.7, 80.0, 72.4, 78.5, 70.4, 79.5, 80.6];
  FemaleValues: TArray<Double> = [83.1, 83.0, 85.3, 83.5, 84.5, 80.6, 84.3, 78.3, 85.1, 84.2];

  { Population shares by age group in 2020, percentage of total, ten countries. }
  ShareYoung: TArray<Double> = [15.6, 16.8, 17.4, 13.8, 12.8, 15.5, 13.3, 16.1, 14.2, 17.7];
  ShareWorking: TArray<Double> = [65.0, 64.0, 61.8, 64.4, 63.8, 66.4, 63.8, 64.9, 66.2, 62.2];
  ShareOld: TArray<Double> = [19.4, 19.2, 20.7, 21.8, 23.4, 18.1, 22.9, 19.0, 19.6, 20.1];

  { Life expectancy in 2020 across all 27 EU member states. }
  EuValues: TArray<Double> = [82.5, 82.4, 82.2, 82.2, 82.2, 82.1, 82.1, 81.9, 81.6, 81.4,
                              81.3, 81.3, 81.2, 81.2, 81.0, 80.7, 80.5, 78.6, 78.2, 77.5,
                              76.9, 76.4, 75.4, 75.2, 75.0, 74.3, 73.4];

  { Sixty years of change, for the countries with a 1960 reading in this set. }
  ChangeCountries: TArray<string> = ['Netherlands', 'Belgium', 'France', 'Germany',
                                     'Poland', 'Portugal', 'Romania'];
  ChangeFrom: TArray<Double> = [73.4, 69.7, 69.9, 69.1, 67.7, 64.0, 65.9];
  ChangeTo: TArray<Double> = [81.4, 80.7, 82.2, 81.0, 76.4, 81.3, 74.3];

  { Population in millions (SP.POP.TOTL), spanning three orders of magnitude. }
  PopulationCountries: TArray<string> = ['Iceland', 'Belgium', 'Netherlands', 'Germany', 'China'];
  PopulationValues: TArray<Double> = [0.4, 11.5, 17.4, 83.2, 1411.1];

  { GDP per capita in current US dollars against life expectancy, bubble size is
    population in millions. Romania, Poland, Portugal, Spain, Italy, France, Belgium,
    Germany, Sweden, Netherlands. }
  GdpPerCapita: TArray<Double> = [13009, 16151, 22299, 27234, 32091, 39170, 45906, 47395, 52569, 53468];

  { The same GDP figures ranked, for the locale formatting example. }
  GdpCountries: TArray<string> = ['Netherlands', 'Sweden', 'Germany', 'Belgium', 'France',
                                  'Italy', 'Spain', 'Portugal', 'Poland', 'Romania'];
  GdpRanked: TArray<Double> = [53468, 52569, 47395, 45906, 39170, 32091, 27234, 22299, 16151, 13009];
  GdpLifeExpectancy: TArray<Double> = [74.3, 76.4, 81.3, 82.2, 82.2, 82.2, 80.7, 81.0, 82.4, 81.4];
  GdpPopulation: TArray<Double> = [19.3, 37.5, 10.3, 47.4, 59.4, 67.6, 11.5, 83.2, 10.4, 17.4];

  { Dutch electricity generation by source in 2020, TWh. }
  ElectricitySources: TArray<string> = ['Fossil', 'Renewable', 'Nuclear'];
  ElectricityValues: TArray<Double> = [85.1, 32.7, 4.1];

const
  { The width a fragment's declaration lines wrap at, matching how the demos display code
    next to a chart (about 76 columns). }
  MaxDeclarationLineWidth = 76;

class function TDemoCatalog.Lines(const Values: array of string): string;
begin
  Result := '';
  for var Index := Low(Values) to High(Values) do
  begin
    const IsFirst = (Index = Low(Values));
    if IsFirst then
      Result := Values[Index]
    else
      Result := Result + sLineBreak + Values[Index];
  end;
end;

class function TDemoCatalog.DeclareStringArray(const VarName: string;
  const Values: TArray<string>): TArray<string>;
const
  ContinuationIndent = '    ';
begin
  var CurrentLine := Format('  %s: TArray<string> = [', [VarName]);
  var HasValueOnLine := False;
  var DeclarationLines: TArray<string> := [];

  for var Index := 0 to High(Values) do
  begin
    const ValueText = QuotedStr(Values[Index]);
    const IsLastValue = (Index = High(Values));
    var Piece: string;
    if IsLastValue then
      Piece := ValueText + '];'
    else
      Piece := ValueText + ', ';

    if HasValueOnLine and (Length(CurrentLine) + Length(Piece) > MaxDeclarationLineWidth) then
    begin
      DeclarationLines := DeclarationLines + [TrimRight(CurrentLine)];
      CurrentLine := ContinuationIndent;
    end;

    CurrentLine := CurrentLine + Piece;
    HasValueOnLine := True;
  end;

  Result := DeclarationLines + [CurrentLine];
end;

class function TDemoCatalog.DeclareDoubleArray(const VarName: string;
  const Values: TArray<Double>; const Decimals: Integer): TArray<string>;
begin
  var CurrentLine := Format('  %s: TArray<Double> = [', [VarName]);
  var Indent := StringOfChar(' ', Length(CurrentLine));
  var HasValueOnLine := False;
  var DeclarationLines: TArray<string> := [];

  for var Index := 0 to High(Values) do
  begin
    const ValueText = Format('%.' + IntToStr(Decimals) + 'f', [Values[Index]], TFormatSettings.Invariant);
    const IsLastValue = (Index = High(Values));
    var Piece: string;
    if IsLastValue then
      Piece := ValueText + '];'
    else
      Piece := ValueText + ', ';

    if HasValueOnLine and (Length(CurrentLine) + Length(Piece) > MaxDeclarationLineWidth) then
    begin
      DeclarationLines := DeclarationLines + [TrimRight(CurrentLine)];
      CurrentLine := Indent;
    end;

    CurrentLine := CurrentLine + Piece;
    HasValueOnLine := True;
  end;

  Result := DeclarationLines + [CurrentLine];
end;

class function TDemoCatalog.DeclareAssignment(const PropertyName, Value: string): TArray<string>;
begin
  const Prefix = Format('  Plot.%s := ', [PropertyName]);
  const Indent = StringOfChar(' ', Length(Prefix));
  const Words = Value.Split([' ']);

  var ChunkText := '';
  var DeclarationLines: TArray<string> := [];

  for var Index := 0 to High(Words) do
  begin
    const IsLastWord = (Index = High(Words));

    var WordPiece := Words[Index];
    if not IsLastWord then
      WordPiece := WordPiece + ' ';

    var LinePrefix := Prefix;
    if Length(DeclarationLines) > 0 then
      LinePrefix := Indent;

    const CandidateChunk = ChunkText + WordPiece;
    const CandidateLength = Length(LinePrefix) + Length(QuotedStr(CandidateChunk)) + Length(' +');

    if (ChunkText <> '') and not IsLastWord and (CandidateLength > MaxDeclarationLineWidth) then
    begin
      DeclarationLines := DeclarationLines + [LinePrefix + QuotedStr(ChunkText) + ' +'];
      ChunkText := '';
    end;

    ChunkText := ChunkText + WordPiece;
  end;

  var FinalPrefix := Prefix;
  if Length(DeclarationLines) > 0 then
    FinalPrefix := Indent;

  Result := DeclarationLines + [FinalPrefix + QuotedStr(ChunkText) + ';'];
end;

class function TDemoCatalog.AssembleCode(const Title, Subtitle, Source: string;
  const ConstDeclarations: TArray<string>; const Body: array of string): string;
begin
  var HeadingLines := DeclareAssignment('Title', Title) + DeclareAssignment('Subtitle', Subtitle);
  if Source <> '' then
    HeadingLines := HeadingLines + DeclareAssignment('Source', Source);

  var BodyLines: TArray<string>;
  SetLength(BodyLines, Length(Body));
  for var Index := Low(Body) to High(Body) do
    BodyLines[Index] := Body[Index];

  const FullBody = HeadingLines + BodyLines;

  var CodeLines: TArray<string>;
  if Length(ConstDeclarations) > 0 then
    CodeLines := ['const'] + ConstDeclarations + ['begin'] + FullBody + ['end;']
  else
    CodeLines := ['begin'] + FullBody + ['end;'];

  Result := Lines(CodeLines);
end;

class function TDemoCatalog.Sample(const Name, Explanation, Title, Subtitle: string;
  const ConstDeclarations: TArray<string>; const Body: array of string;
  const Build: TDemoBuildProc): TDemoSample;
begin
  Result := Sample(Name, Explanation, Title, Subtitle, '', ConstDeclarations, Body, Build);
end;

class function TDemoCatalog.Sample(const Name, Explanation, Title, Subtitle, Source: string;
  const ConstDeclarations: TArray<string>; const Body: array of string;
  const Build: TDemoBuildProc): TDemoSample;
begin
  Result.Name := Name;
  Result.Explanation := Explanation;
  Result.Code := AssembleCode(Title, Subtitle, Source, ConstDeclarations, Body);
  Result.Build :=
    procedure(const Plot: TChartPlot)
    begin
      Plot.Title := Title;
      Plot.Subtitle := Subtitle;
      if Source <> '' then
        Plot.Source := Source;
      Build(Plot);
    end;
end;

class function TDemoCatalog.DefaultSource: string;
begin
  Result := WorldBankSource;
end;

class function TDemoCatalog.Samples: TArray<TDemoSample>;
begin
  Result := [
    Sample('Line',
      'One measure over time, drawn as a continuous path. The reader follows the ' +
      'shape rather than reading values off the axis, so a line answers how ' +
      'something moved rather than exactly where it stood. A denser reading interval ' +
      'shows turns that a coarser one smooths away.',
      'Rising life expectancy', 'Netherlands, 1960-2020',
      DeclareDoubleArray('Years', DenseYears, 0) + DeclareDoubleArray('Dutch', DenseDutch, 1),
      ['  Plot.Kind := TChartKind.Line;',
       '  Plot.AddLineSeries(''Netherlands'', Years, Dutch);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Line;
        Plot.AddLineSeries('Netherlands', DenseYears, DenseDutch);
      end),

    Sample('Multi-line',
      'Several series in one chart, each taking the next colour from the palette. ' +
      'Use it to compare shapes rather than exact values, because the reader follows ' +
      'lines and not numbers. Three or four is about the limit before the chart ' +
      'turns into a plate of spaghetti.',
      'Converging, then diverging', 'Life expectancy, 1960-2020',
      DeclareDoubleArray('Years', DenseYears, 0) +
      DeclareDoubleArray('Dutch', DenseDutch, 1) +
      DeclareDoubleArray('French', DenseFrench, 1) +
      DeclareDoubleArray('Polish', DensePolish, 1),
      ['  Plot.Kind := TChartKind.Line;',
       '  Plot.AddLineSeries(''Netherlands'', Years, Dutch);',
       '  Plot.AddLineSeries(''France'', Years, French);',
       '  Plot.AddLineSeries(''Poland'', Years, Polish);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Line;
        Plot.AddLineSeries('Netherlands', DenseYears, DenseDutch);
        Plot.AddLineSeries('France', DenseYears, DenseFrench);
        Plot.AddLineSeries('Poland', DenseYears, DensePolish);
      end),

    Sample('Area',
      'A line with the space beneath it filled. The fill suggests a quantity ' +
      'accumulating rather than a level being measured, so it suits volumes and ' +
      'totals better than rates and ratios. With more than one series the fills hide ' +
      'each other, so keep it to one.',
      'The internet arrives', 'Share of the Dutch population online',
      DeclareDoubleArray('Years', InternetYears, 0) +
      DeclareDoubleArray('Online', InternetDutch, 1),
      ['  Plot.Kind := TChartKind.Area;',
       '  Plot.AddLineSeries(''Netherlands'', Years, Online);',
       '',
       '  var YAxis := Plot.YAxis;',
       '  YAxis.LabelSuffix := ''%'';',
       '  Plot.YAxis := YAxis;'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Area;
        Plot.AddLineSeries('Netherlands', InternetYears, InternetDutch);

        var YAxis := Plot.YAxis;
        YAxis.LabelSuffix := '%';
        Plot.YAxis := YAxis;
      end),

    Sample('Bar (horizontal)',
      'Ranking a set of categories against each other. A bar is read by its length, ' +
      'so its axis has to start at zero, which makes the bar chart right for ' +
      'quantities that can genuinely be zero and wrong for measures that never ' +
      'approach it. Horizontal bars give long category names their own row, so ' +
      'nothing has to be rotated or shortened.',
      'Almost everyone is online', 'Share of the population using the internet, 2020',
      DeclareStringArray('Countries', OnlineCountries) +
      DeclareDoubleArray('Online', OnlineShare2020, 1),
      ['  Plot.Kind := TChartKind.Bar;',
       '  Plot.Orientation := TChartOrientation.Horizontal;',
       '  Plot.Categories := Countries;',
       '  Plot.AddSeries(''2020'', Online);',
       '',
       '  // For a horizontal chart the value axis is still YAxis: the',
       '  // orientation swaps where the axes are drawn, not what they mean.',
       '  var YAxis := Plot.YAxis;',
       '  YAxis.LabelSuffix := ''%'';',
       '  Plot.YAxis := YAxis;'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Bar;
        Plot.Orientation := TChartOrientation.Horizontal;
        Plot.Categories := OnlineCountries;
        Plot.AddSeries('2020', OnlineShare2020);

        var YAxis := Plot.YAxis;
        YAxis.LabelSuffix := '%';
        Plot.YAxis := YAxis;
      end),

    Sample('Grouped bar',
      'Two or three measures per category, side by side. Because bars run from zero, ' +
      'a pair only reads well when the difference is a real fraction of the whole; ' +
      'values that sit close together become bars that look the same. Every extra ' +
      'series also halves the width of each bar, so this kind runs out of room ' +
      'quickly.',
      'Emissions per person, then and now', 'Tonnes of CO2 per capita, 1990 and 2020',
      DeclareStringArray('Countries', TenCountries) +
      DeclareDoubleArray('In1990', Emissions1990, 1) +
      DeclareDoubleArray('In2020', Emissions2020, 1),
      ['  Plot.Kind := TChartKind.GroupedBar;',
       '  Plot.Orientation := TChartOrientation.Horizontal;',
       '  Plot.Categories := Countries;',
       '  Plot.AddSeries(''1990'', In1990);',
       '  Plot.AddSeries(''2020'', In2020);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.GroupedBar;
        Plot.Orientation := TChartOrientation.Horizontal;
        Plot.Categories := TenCountries;
        Plot.AddSeries('1990', Emissions1990);
        Plot.AddSeries('2020', Emissions2020);
      end),

    Sample('Stacked bar (proportions)',
      'Parts of a whole, compared across categories. In proportional mode every bar ' +
      'is normalised to 100%, so the reader compares shares rather than sizes. Only ' +
      'the bottom and top bands sit on a common edge and are easy to compare, so put ' +
      'the segment that matters at the bottom.',
      'An ageing continent', 'Share of population by age group, 2020',
      DeclareStringArray('Countries', TenCountries) +
      DeclareDoubleArray('Young', ShareYoung, 1) +
      DeclareDoubleArray('Working', ShareWorking, 1) +
      DeclareDoubleArray('Old', ShareOld, 1),
      ['  Plot.Kind := TChartKind.StackedBar;',
       '  Plot.StackMode := TStackMode.Proportions;',
       '  Plot.Orientation := TChartOrientation.Horizontal;',
       '  Plot.Categories := Countries;',
       '  Plot.AddSeries(''0-14'', Young);',
       '  Plot.AddSeries(''15-64'', Working);',
       '  Plot.AddSeries(''65+'', Old);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.StackedBar;
        Plot.StackMode := TStackMode.Proportions;
        Plot.Orientation := TChartOrientation.Horizontal;
        Plot.Categories := TenCountries;
        Plot.AddSeries('0-14', ShareYoung);
        Plot.AddSeries('15-64', ShareWorking);
        Plot.AddSeries('65+', ShareOld);
      end),

    Sample('Histogram',
      'The shape of a distribution. Give it raw values and a bin width and it counts ' +
      'them into buckets itself, so a bar height is a frequency rather than a ' +
      'measured value. The bin width is an editorial choice: too wide hides ' +
      'structure, too narrow turns the distribution into noise.',
      'How life expectancy varies', 'Distribution across the 27 EU countries, 2020',
      DeclareDoubleArray('Values', EuValues, 1),
      ['  Plot.SetHistogramData(Values, 2.0);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.SetHistogramData(EuValues, 2.0);
      end),

    Sample('Dumbbell',
      'Change between two moments, one row per category. The eye reads the length of ' +
      'the connector as the size of the change, which no pair of bars manages as ' +
      'directly. Orange marks the start and blue the end, so the direction is ' +
      'visible without a legend.',
      'We are living longer', 'Life expectancy, 1960 versus 2020',
      DeclareStringArray('Countries', ChangeCountries) +
      DeclareDoubleArray('From1960', ChangeFrom, 1) +
      DeclareDoubleArray('To2020', ChangeTo, 1),
      ['  Plot.Categories := Countries;',
       '  Plot.AddDumbbellSeries(From1960, To2020);',
       '',
       '  // The annotation sits on Portugal''s connector, midway between its',
       '  // two dots, rather than at the end where it would float free.',
       '  Plot.AddTextAnnotation(5, 72.5, ''+17.3 years'', ChartDarkRed,',
       '                         TTextAlignH.Center);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Categories := ChangeCountries;
        Plot.AddDumbbellSeries(ChangeFrom, ChangeTo);
        Plot.AddTextAnnotation(5, 72.5, '+17.3 years', ChartDarkRed, TTextAlignH.Center);
      end),

    Sample('Value labels (extremes)',
      'Direct labelling instead of an axis lookup. Extremes mode labels the highest ' +
      'and lowest point of every series; the other modes label every point, or the ' +
      'first and last. A label that would cover an axis number is moved inside the ' +
      'plot, and one that would collide with a label already drawn is skipped, so ' +
      'the result stays readable without any manual placement.',
      'Direct labelling', 'Extremes of both series, labelled automatically',
      DeclareDoubleArray('Years', InternetYears, 0) +
      DeclareDoubleArray('Dutch', InternetDutch, 1) +
      DeclareDoubleArray('Romanian', InternetRomanian, 1),
      ['  Plot.Kind := TChartKind.Line;',
       '  Plot.AddLineSeries(''Netherlands'', Years, Dutch);',
       '  Plot.AddLineSeries(''Romania'', Years, Romanian);',
       '  Plot.ValueLabels := TValueLabelMode.Extremes;',
       '  // also available: None, All, FirstAndLast'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Line;
        Plot.AddLineSeries('Netherlands', InternetYears, InternetDutch);
        Plot.AddLineSeries('Romania', InternetYears, InternetRomanian);
        Plot.ValueLabels := TValueLabelMode.Extremes;
      end),

    Sample('Series highlighting',
      'One series in colour, the rest in grey. This is the most common editorial ' +
      'move there is: the chart shows the context but argues a single point. Only ' +
      'series without an explicit colour are muted, so a colour you set yourself ' +
      'always survives.',
      'Romania caught up fastest', 'Share of the population online',
      DeclareDoubleArray('Years', InternetYears, 0) +
      DeclareDoubleArray('Dutch', InternetDutch, 1) +
      DeclareDoubleArray('Belgian', InternetBelgian, 1) +
      DeclareDoubleArray('German', InternetGerman, 1) +
      DeclareDoubleArray('Polish', InternetPolish, 1) +
      DeclareDoubleArray('Romanian', InternetRomanian, 1),
      ['  Plot.Kind := TChartKind.Line;',
       '  Plot.AddLineSeries(''Netherlands'', Years, Dutch);',
       '  Plot.AddLineSeries(''Belgium'', Years, Belgian);',
       '  Plot.AddLineSeries(''Germany'', Years, German);',
       '  Plot.AddLineSeries(''Poland'', Years, Polish);',
       '',
       '  // The fifth palette colour is a dark grey, which would not read as',
       '  // a highlight against muted series, so this one states its colour.',
       '  // An explicit colour survives muting.',
       '  const Romania = Plot.AddLineSeries(''Romania'', Years, Romanian);',
       '  Romania.Color := ChartBlue;',
       '',
       '  Plot.HighlightedSeriesIndex := 4;'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Line;
        Plot.AddLineSeries('Netherlands', InternetYears, InternetDutch);
        Plot.AddLineSeries('Belgium', InternetYears, InternetBelgian);
        Plot.AddLineSeries('Germany', InternetYears, InternetGerman);
        Plot.AddLineSeries('Poland', InternetYears, InternetPolish);

        const Romania = Plot.AddLineSeries('Romania', InternetYears, InternetRomanian);
        Romania.Color := ChartBlue;

        Plot.HighlightedSeriesIndex := 4;
      end),

    Sample('Locale number format',
      'Axis numbers follow the invariant convention by default, so output stays ' +
      'reproducible whatever machine it runs on, which is what tests need. Set a ' +
      'locale when the chart is for readers instead, and the decimal and thousand ' +
      'separators swap to that convention. It only shows on numbers large or precise ' +
      'enough to be grouped.',
      'Dutch number format', 'GDP per capita in US dollars, 2020, grouped the Dutch way',
      DeclareStringArray('Countries', GdpCountries) +
      DeclareDoubleArray('Gdp', GdpRanked, 0),
      ['  Plot.Kind := TChartKind.Bar;',
       '  Plot.Orientation := TChartOrientation.Horizontal;',
       '  Plot.Categories := Countries;',
       '  Plot.AddSeries(''2020'', Gdp);',
       '',
       '  var YAxis := Plot.YAxis;',
       '  YAxis.UseThousandSeparator := True;',
       '  YAxis.LocaleName := ''nl-NL'';',
       '  Plot.YAxis := YAxis;'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Bar;
        Plot.Orientation := TChartOrientation.Horizontal;
        Plot.Categories := GdpCountries;
        Plot.AddSeries('2020', GdpRanked);

        var YAxis := Plot.YAxis;
        YAxis.UseThousandSeparator := True;
        YAxis.LocaleName := 'nl-NL';
        Plot.YAxis := YAxis;
      end),

    Sample('Uncertainty band',
      'A band between a low and a high series, drawn behind the lines. Use it for a ' +
      'confidence interval, a forecast range, or any real spread around a central ' +
      'value. Give the band a translucent colour so whatever runs on top of it stays ' +
      'legible. Here the band is the published 95% interval around each reading, so it ' +
      'narrows as the measurement network improves: the chart states both what was ' +
      'measured and how well it was known.',
      'Warmer, and better measured',
      'Global temperature anomaly against the 1961-1990 average, in degrees Celsius',
      HadCrutSource,
      DeclareDoubleArray('Years', AnomalyYears, 0) +
      DeclareDoubleArray('Low', AnomalyLow, 2) +
      DeclareDoubleArray('High', AnomalyHigh, 2) +
      DeclareDoubleArray('Best', AnomalyBest, 2),
      ['  Plot.Kind := TChartKind.Line;',
       '  const Band = Plot.AddRangeBandSeries(''95% interval'', Years,',
       '                                       Low, High);',
       '  Band.Color := TAlphaColor($3013A0C1);',
       '',
       '  // Give the line a solid blue close to the band colour, so the two',
       '  // read as one statement instead of two unrelated series.',
       '  const Line = Plot.AddLineSeries(''Best estimate'', Years, Best);',
       '  Line.Color := ChartBlue;'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Line;

        const Band = Plot.AddRangeBandSeries('95% interval', AnomalyYears,
                                             AnomalyLow, AnomalyHigh);
        Band.Color := TAlphaColor($3013A0C1);

        const Line = Plot.AddLineSeries('Best estimate', AnomalyYears, AnomalyBest);
        Line.Color := ChartBlue;
      end),

    Sample('Shaded range overlay',
      'A shaded zone across the whole plot, in axis coordinates rather than from ' +
      'data. Use it to mark a target corridor, a period, or any region the reader ' +
      'should judge the series against. It sits behind the series and takes no part ' +
      'in hit testing, so it never steals a tooltip.',
      'A target corridor', 'Life expectancy against a target of 78 to 80 years',
      DeclareDoubleArray('Years', DenseYears, 0) + DeclareDoubleArray('Dutch', DenseDutch, 1),
      ['  Plot.Kind := TChartKind.Line;',
       '  Plot.AddLineSeries(''Netherlands'', Years, Dutch);',
       '  Plot.AddHorizontalRangeOverlay(78, 80, TAlphaColor($30990000));'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Line;
        Plot.AddLineSeries('Netherlands', DenseYears, DenseDutch);
        Plot.AddHorizontalRangeOverlay(78, 80, TAlphaColor($30990000));
      end),

    Sample('Logarithmic axis',
      'When the largest value is orders of magnitude above the smallest, a linear ' +
      'axis flattens everything except the giant. A logarithmic axis gives each ' +
      'order of magnitude the same space, so the small values keep their shape. Zero ' +
      'and negative values have no logarithm, so they raise rather than draw ' +
      'something misleading.',
      'Populations span orders of magnitude', 'Population in millions, 2020, logarithmic axis',
      DeclareStringArray('Countries', PopulationCountries) +
      DeclareDoubleArray('Millions', PopulationValues, 1),
      ['  Plot.Kind := TChartKind.Bar;',
       '  Plot.Categories := Countries;',
       '  Plot.AddSeries(''Population'', Millions);',
       '',
       '  // The values are already in millions, so an M suffix on top of',
       '  // that would say it twice. The subtitle carries the unit.',
       '  var YAxis := Plot.YAxis;',
       '  YAxis.Scale := TAxisScaleKind.Logarithmic;',
       '  Plot.YAxis := YAxis;'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Bar;
        Plot.Categories := PopulationCountries;
        Plot.AddSeries('Population', PopulationValues);

        var YAxis := Plot.YAxis;
        YAxis.Scale := TAxisScaleKind.Logarithmic;
        Plot.YAxis := YAxis;
      end),

    Sample('Date axis',
      'Feed the X axis real dates instead of plain numbers and it chooses its own ' +
      'interval, from days through months and quarters to years, based on the range ' +
      'it is given. Without it a time series is just numbers on an axis and every ' +
      'label has to be written by hand.',
      'A date-aware X axis', 'Netherlands, by year of measurement',
      DeclareDoubleArray('Years', DenseYears, 0) + DeclareDoubleArray('Dutch', DenseDutch, 1),
      ['  Plot.Kind := TChartKind.Line;',
       '',
       '  var XAxis := Plot.XAxis;',
       '  XAxis.DateMode := TAxisDateMode.Auto;',
       '  Plot.XAxis := XAxis;',
       '',
       '  var Dates: TArray<Double>;',
       '  SetLength(Dates, Length(Years));',
       '  for var Index := 0 to High(Years) do',
       '    Dates[Index] := EncodeDate(Round(Years[Index]), 1, 1);',
       '',
       '  Plot.AddLineSeries(''Netherlands'', Dates, Dutch);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Line;

        var XAxis := Plot.XAxis;
        XAxis.DateMode := TAxisDateMode.Auto;
        Plot.XAxis := XAxis;

        var Dates: TArray<Double>;
        SetLength(Dates, Length(DenseYears));
        for var Index := 0 to High(DenseYears) do
        begin
          Dates[Index] := EncodeDate(Round(DenseYears[Index]), 1, 1);
        end;

        Plot.AddLineSeries('Netherlands', Dates, DenseDutch);
      end),

    Sample('Scatter (bubble)',
      'Two continuous measures against each other, one point per case, with the ' +
      'point size carrying a third. Bubble area maps to the value rather than the ' +
      'radius, because doubling a radius quadruples the ink and would overstate the ' +
      'difference fourfold. The value axis does not force zero into range, since a ' +
      'scatter is about position rather than length.',
      'Richer countries live longer', 'Bubble size shows population, 2020',
      DeclareDoubleArray('Gdp', GdpPerCapita, 0) +
      DeclareDoubleArray('Life', GdpLifeExpectancy, 1) +
      DeclareDoubleArray('Millions', GdpPopulation, 1),
      ['  Plot.Kind := TChartKind.Scatter;',
       '  const Series = Plot.AddLineSeries(''Countries'', Gdp, Life);',
       '  Series.Sizes := Millions;',
       '',
       '  // Four and five figure amounts need grouping to be read at a',
       '  // glance, and the unit belongs on the last label only.',
       '  var XAxis := Plot.XAxis;',
       '  XAxis.UseThousandSeparator := True;',
       '  XAxis.LabelSuffix := '' USD'';',
       '  Plot.XAxis := XAxis;',
       '',
       '  var YAxis := Plot.YAxis;',
       '  YAxis.LabelSuffix := '' years'';',
       '  Plot.YAxis := YAxis;'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Scatter;

        const Series = Plot.AddLineSeries('Countries', GdpPerCapita, GdpLifeExpectancy);
        Series.Sizes := GdpPopulation;

        var XAxis := Plot.XAxis;
        XAxis.UseThousandSeparator := True;
        XAxis.LabelSuffix := ' USD';
        Plot.XAxis := XAxis;

        var YAxis := Plot.YAxis;
        YAxis.LabelSuffix := ' years';
        Plot.YAxis := YAxis;
      end),

    Sample('Dot plot',
      'The chart to reach for when zero is not informative. Bars from a zero ' +
      'baseline make values that sit in a narrow band look identical, while a dot ' +
      'placed on the value shows the spread honestly without implying that a length ' +
      'means anything. It also uses a fraction of the ink, so many categories stay ' +
      'legible.',
      'Sweden is highest, Romania lowest', 'Life expectancy at birth, 2020',
      DeclareStringArray('Countries', RankedCountries) +
      DeclareDoubleArray('Values', RankedValues, 1),
      ['  Plot.Kind := TChartKind.DotPlot;',
       '  Plot.Orientation := TChartOrientation.Horizontal;',
       '  Plot.Categories := Countries;',
       '  Plot.AddSeries(''2020'', Values);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.DotPlot;
        Plot.Orientation := TChartOrientation.Horizontal;
        Plot.Categories := RankedCountries;
        Plot.AddSeries('2020', RankedValues);
      end),

    Sample('Range plot',
      'A bar spanning a low and a high value per category. The same data a dumbbell ' +
      'shows, but the filled bar makes the size of the span the subject instead of ' +
      'the two endpoints. Use it when the width of the gap is the story.',
      'The gap between men and women', 'Life expectancy by sex, 2020',
      DeclareStringArray('Countries', TenCountries) +
      DeclareDoubleArray('Men', MaleValues, 1) +
      DeclareDoubleArray('Women', FemaleValues, 1),
      ['  Plot.Categories := Countries;',
       '  Plot.AddRangeSeries(''Male to female'', Men, Women);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Categories := TenCountries;
        Plot.AddRangeSeries('Male to female', MaleValues, FemaleValues);
      end),

    Sample('Arrow plot',
      'A dumbbell that states its direction. Use it when the movement is the story ' +
      'and its sign is not obvious in advance, so the reader sees at a glance which ' +
      'way each category went.',
      'Every country emits less per person', 'Tonnes of CO2 per capita, 1990 to 2020',
      DeclareStringArray('Countries', TenCountries) +
      DeclareDoubleArray('In1990', Emissions1990, 1) +
      DeclareDoubleArray('In2020', Emissions2020, 1),
      ['  Plot.Categories := Countries;',
       '  Plot.AddArrowSeries(''Change'', In1990, In2020);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Categories := TenCountries;
        Plot.AddArrowSeries('Change', Emissions1990, Emissions2020);
      end),

    Sample('Pie',
      'Parts of one whole, and nothing else. It works for a handful of segments ' +
      'where one clearly dominates, and falls apart beyond that because people ' +
      'compare angles poorly. Segments are labelled directly with their share, so ' +
      'the reader never has to consult a legend.',
      'Where Dutch electricity came from', 'Generation by source, 2020, TWh', EmberSource,
      DeclareStringArray('Sources', ElectricitySources) +
      DeclareDoubleArray('TWh', ElectricityValues, 1),
      ['  Plot.Kind := TChartKind.Pie;',
       '  Plot.Categories := Sources;',
       '  Plot.AddSeries(''Generation'', TWh);'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Pie;
        Plot.Categories := ElectricitySources;
        Plot.AddSeries('Generation', ElectricityValues);
      end),

    Sample('Donut',
      'A pie with the middle removed, which buys room for a total. Reading it means ' +
      'comparing arc lengths rather than angles, which people do slightly better. ' +
      'The centre text is yours to format.',
      'Where Dutch electricity came from', 'Generation by source, 2020, TWh', EmberSource,
      DeclareStringArray('Sources', ElectricitySources) +
      DeclareDoubleArray('TWh', ElectricityValues, 1),
      ['  Plot.Kind := TChartKind.Donut;',
       '  Plot.Categories := Sources;',
       '  Plot.AddSeries(''Generation'', TWh);',
       '  Plot.DonutCenterText := ''121.9 TWh'';'],
      procedure(const Plot: TChartPlot)
      begin
        Plot.Kind := TChartKind.Donut;
        Plot.Categories := ElectricitySources;
        Plot.AddSeries('Generation', ElectricityValues);
        Plot.DonutCenterText := '121.9 TWh';
      end)
  ];
end;

end.
