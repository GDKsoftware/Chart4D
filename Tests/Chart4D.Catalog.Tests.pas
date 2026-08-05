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
unit Chart4D.Catalog.Tests;

/// <summary>
/// Proves that a demo catalogue entry's <c>Code</c> fragment agrees with the data its
/// <c>Build</c> procedure actually hands to the chart. The fragment's declaration lines are
/// generated from the same constants <c>Build</c> uses (see <c>Chart4DDemo.Catalog</c>), so
/// this test parses the numbers and names back out of the rendered fragment and checks them
/// against the plot <c>Build</c> produces, rather than trusting the generator by inspection.
/// </summary>

interface

uses
  DUnitX.TestFramework,
  Chart4DDemo.Catalog;

type
  [TestFixture]
  TCatalogDataAgreementTests = class
  private
    /// <summary>Finds a sample by its catalogue name, or fails the test if it is not there.</summary>
    function FindSample(const Name: string): TDemoSample;

    /// <summary>
    /// Parses the values out of a <c>VarName: TArray&lt;Double&gt; = [...]</c> declaration
    /// inside Code, in the order they appear, regardless of how the declaration is wrapped
    /// across lines.
    /// </summary>
    function ExtractDoubles(const Code, VarName: string): TArray<Double>;

    /// <summary>
    /// Parses the quoted values out of a <c>VarName: TArray&lt;string&gt; = [...]</c>
    /// declaration inside Code, in the order they appear.
    /// </summary>
    function ExtractStrings(const Code, VarName: string): TArray<string>;

    /// <summary>
    /// Reconstructs the string a <c>Plot.PropertyName := '...';</c> assignment inside Code
    /// produces, whether it is a single literal or several concatenated with <c>+</c> across
    /// wrapped lines, by concatenating every quoted literal found between the assignment and
    /// its terminating semicolon, in order.
    /// </summary>
    function ExtractAssignedString(const Code, PropertyName: string): string;

    procedure AssertDoublesEqual(const Expected, Actual: TArray<Double>; const Context: string);
    procedure AssertStringsEqual(const Expected, Actual: TArray<string>; const Context: string);

  public
    [Test]
    procedure Line_CodeDeclarations_MatchBuildData;

    [Test]
    procedure GroupedBar_CodeDeclarations_MatchBuildData;

    [Test]
    procedure RangePlot_CodeDeclarations_MatchBuildData;

    [Test]
    procedure Pie_CodeDeclarations_MatchBuildData;

    [Test]
    procedure UncertaintyBand_CodeDeclarations_MatchBuildData;

    [Test]
    procedure AllSamples_Heading_MatchesBuildData;
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  Chart4D.Plot;

function TCatalogDataAgreementTests.FindSample(const Name: string): TDemoSample;
begin
  for var Candidate in TDemoCatalog.Samples do
  begin
    if Candidate.Name = Name then
      Exit(Candidate);
  end;
  Assert.Fail(Format('No catalogue sample named "%s"', [Name]));
end;

function TCatalogDataAgreementTests.ExtractDoubles(const Code, VarName: string): TArray<Double>;
begin
  const Pattern = Format('%s\s*:\s*TArray<Double>\s*=\s*\[(.*?)\]', [TRegEx.Escape(VarName)]);
  const Match = TRegEx.Match(Code, Pattern, [roSingleLine]);
  Assert.IsTrue(Match.Success, Format('No TArray<Double> declaration for "%s" found in Code', [VarName]));

  const Tokens = Match.Groups[1].Value.Split([',']);
  SetLength(Result, Length(Tokens));
  for var Index := Low(Tokens) to High(Tokens) do
    Result[Index] := StrToFloat(Trim(Tokens[Index]), TFormatSettings.Invariant);
end;

function TCatalogDataAgreementTests.ExtractStrings(const Code, VarName: string): TArray<string>;
begin
  const Pattern = Format('%s\s*:\s*TArray<string>\s*=\s*\[(.*?)\]', [TRegEx.Escape(VarName)]);
  const Match = TRegEx.Match(Code, Pattern, [roSingleLine]);
  Assert.IsTrue(Match.Success, Format('No TArray<string> declaration for "%s" found in Code', [VarName]));

  const Matches = TRegEx.Matches(Match.Groups[1].Value, '''([^'']*)''');
  SetLength(Result, Matches.Count);
  for var Index := 0 to Matches.Count - 1 do
    Result[Index] := Matches[Index].Groups[1].Value;
end;

function TCatalogDataAgreementTests.ExtractAssignedString(const Code, PropertyName: string): string;
begin
  const Pattern = Format('Plot\.%s\s*:=\s*(.*?);', [TRegEx.Escape(PropertyName)]);
  const Match = TRegEx.Match(Code, Pattern, [roSingleLine]);
  Assert.IsTrue(Match.Success, Format('No Plot.%s assignment found in Code', [PropertyName]));

  const LiteralMatches = TRegEx.Matches(Match.Groups[1].Value, '''([^'']*)''');
  Result := '';
  for var LiteralMatch in LiteralMatches do
    Result := Result + LiteralMatch.Groups[1].Value;
end;

procedure TCatalogDataAgreementTests.AssertDoublesEqual(const Expected, Actual: TArray<Double>; const Context: string);
begin
  Assert.AreEqual(Length(Expected), Length(Actual), Context + ': length mismatch');
  for var Index := Low(Expected) to High(Expected) do
    Assert.AreEqual(Expected[Index], Actual[Index], 1E-9, Format('%s[%d]', [Context, Index]));
end;

procedure TCatalogDataAgreementTests.AssertStringsEqual(const Expected, Actual: TArray<string>; const Context: string);
begin
  Assert.AreEqual(Length(Expected), Length(Actual), Context + ': length mismatch');
  for var Index := Low(Expected) to High(Expected) do
    Assert.AreEqual(Expected[Index], Actual[Index], Context + Format('[%d]', [Index]));
end;

procedure TCatalogDataAgreementTests.Line_CodeDeclarations_MatchBuildData;
begin
  const Sample = FindSample('Line');
  const Plot = TChartPlot.Create;
  try
    Sample.Build(Plot);

    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'Years'), Plot.Series[0].XValues, 'Years');
    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'Dutch'), Plot.Series[0].Values, 'Dutch');
  finally
    Plot.Free;
  end;
end;

procedure TCatalogDataAgreementTests.GroupedBar_CodeDeclarations_MatchBuildData;
begin
  const Sample = FindSample('Grouped bar');
  const Plot = TChartPlot.Create;
  try
    Sample.Build(Plot);

    AssertStringsEqual(ExtractStrings(Sample.Code, 'Countries'), Plot.Categories, 'Countries');
    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'In1990'), Plot.Series[0].Values, 'In1990');
    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'In2020'), Plot.Series[1].Values, 'In2020');
  finally
    Plot.Free;
  end;
end;

{ The only example whose declarations carry two decimals, and the only one whose band and
  line are separate series, so it is worth checking that the fragment reproduces both. }
procedure TCatalogDataAgreementTests.UncertaintyBand_CodeDeclarations_MatchBuildData;
begin
  const Sample = FindSample('Uncertainty band');
  const Plot = TChartPlot.Create;
  try
    Sample.Build(Plot);

    const Band = Plot.Series[0];
    const Line = Plot.Series[1];

    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'Years'), Band.XValues, 'Years');
    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'Low'), Band.Values, 'Low');
    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'High'), Band.EndValues, 'High');
    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'Best'), Line.Values, 'Best');

    Assert.IsTrue(Band.IsRangeBand, 'the first series should be the range band');
    Assert.IsFalse(Line.IsRangeBand, 'the second series should be the plain line');
  finally
    Plot.Free;
  end;
end;

procedure TCatalogDataAgreementTests.RangePlot_CodeDeclarations_MatchBuildData;
begin
  const Sample = FindSample('Range plot');
  const Plot = TChartPlot.Create;
  try
    Sample.Build(Plot);

    AssertStringsEqual(ExtractStrings(Sample.Code, 'Countries'), Plot.Categories, 'Countries');
    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'Men'), Plot.Series[0].Values, 'Men');
    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'Women'), Plot.Series[0].EndValues, 'Women');
  finally
    Plot.Free;
  end;
end;

procedure TCatalogDataAgreementTests.Pie_CodeDeclarations_MatchBuildData;
begin
  const Sample = FindSample('Pie');
  const Plot = TChartPlot.Create;
  try
    Sample.Build(Plot);

    AssertStringsEqual(ExtractStrings(Sample.Code, 'Sources'), Plot.Categories, 'Sources');
    AssertDoublesEqual(ExtractDoubles(Sample.Code, 'TWh'), Plot.Series[0].Values, 'TWh');
  finally
    Plot.Free;
  end;
end;

procedure TCatalogDataAgreementTests.AllSamples_Heading_MatchesBuildData;
begin
  for var Candidate in TDemoCatalog.Samples do
  begin
    const Plot = TChartPlot.Create;
    try
      Candidate.Build(Plot);

      const ExtractedTitle = ExtractAssignedString(Candidate.Code, 'Title');
      Assert.AreEqual(Plot.Title, ExtractedTitle, Candidate.Name + ': Title');

      const ExtractedSubtitle = ExtractAssignedString(Candidate.Code, 'Subtitle');
      Assert.AreEqual(Plot.Subtitle, ExtractedSubtitle, Candidate.Name + ': Subtitle');

      const HasSourceAssignment = TRegEx.IsMatch(Candidate.Code, 'Plot\.Source\s*:=');
      if Plot.Source <> '' then
      begin
        Assert.IsTrue(HasSourceAssignment,
          Candidate.Name + ': Plot.Source is set but Code has no Source assignment');
        Assert.AreEqual(Plot.Source, ExtractAssignedString(Candidate.Code, 'Source'),
          Candidate.Name + ': Source');
      end
      else
        Assert.IsFalse(HasSourceAssignment,
          Candidate.Name + ': Code states a Source the plot never receives');
    finally
      Plot.Free;
    end;
  end;
end;

end.
