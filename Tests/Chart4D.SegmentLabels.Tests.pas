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
unit Chart4D.SegmentLabels.Tests;

/// <summary>
/// Tests for the segment labels of <c>Pie</c> and <c>Donut</c> charts: that no wedge is
/// drawn over a label, and which labels win when two would collide. See SPEC.md 4.23.
/// </summary>

interface

uses
  System.Types,
  System.UITypes,
  DUnitX.TestFramework,
  Chart4D.Axis,
  Chart4D.Tests.Asserts,
  Chart4D.Canvas.Interfaces,
  Chart4D.Style,
  Chart4D.Tests.RecordingCanvas,
  Chart4D.Types;

type
  [TestFixture]
  TSegmentLabelTests = class
  private
    FCanvas: IChartCanvas;
    FRecordingCanvas: TRecordingCanvas;

    procedure RenderPie(const Kind: TChartKind; const Categories: TArray<string>;
                        const Values: TArray<Double>;
                        const LabelBackground: TAlphaColor = ChartLabelBackground);
    function SegmentLabelCall(const Text: string): TCanvasCall;
    function RenderThirds(const Mode: TSegmentLabelMode;
                          const LabelBackground: TAlphaColor = ChartLabelBackground): TArray<TChartHitTarget>;
    function RenderThirdsWithStyle(const Mode: TSegmentLabelMode; const Style: TChartStyle): TArray<TChartHitTarget>;
    procedure RenderThirdsWithDecimals(const SegmentLabelDecimals: Integer; const YAxis: TAxisOptions);
    function BoxlessStyleWithMinimumContrast(const MinimumContrast: Double): TChartStyle;
    function LastCallIndexOfKind(const Kind: TCanvasCallKind): Integer;
    function CountOfText(const Text: string): Integer;
    procedure AssertEveryLabelDrawnAfterTheLastWedge;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure PieChart_EveryLabel_IsDrawnAfterTheLastWedge;

    [Test]
    procedure DonutChart_EveryLabel_IsDrawnAfterTheLastWedge;

    [Test]
    procedure PieChart_SmallSegmentBeforeALargerOne_NeverDisplacesTheLargerLabel;

    [Test]
    procedure PieChart_EqualSegmentsThatCollide_KeepTheEarlierCategory;

    [Test]
    procedure SegmentLabels_CategoryAndPercentage_ShowsBoth;

    [Test]
    procedure SegmentLabels_Percentage_ShowsTheShareAlone;

    [Test]
    procedure SegmentLabels_Category_ShowsTheCategoryAlone;

    [Test]
    procedure SegmentLabels_None_DrawsNoLabelsButKeepsTheHitTargets;

    [Test]
    procedure SegmentLabelDecimals_One_ShowsOneDecimal;

    [Test]
    procedure SegmentLabelDecimals_Automatic_IgnoresTheValueAxisDecimals;

    [Test]
    procedure SegmentLabelDecimals_DutchValueAxisLocale_UsesCommaDecimalSeparator;

    [Test]
    procedure LabelBackground_Default_DrawsWhiteBoxesWithTheStyleTextColor;

    [Test]
    procedure LabelBackground_CustomOpaqueColor_FillsEveryLabelBox;

    [Test]
    procedure LabelBackground_Transparent_DrawsTheTextWithoutABox;

    [Test]
    procedure LabelBackground_Transparent_GivesEachLabelTextThatContrastsWithItsWedge;

    [Test]
    procedure LabelBackground_Transparent_StillDropsACollidingLabel;

    [Test]
    procedure MinimumTextContrast_Three_KeepsDarkTextOnTheBlueWedgeOnly;

    [Test]
    procedure MinimumTextContrast_One_KeepsTheStyleTextColorOnEveryWedge;

    [Test]
    procedure TextContrast_CustomPalette_IsJudgedAgainstThePaletteColor;
  end;

implementation

uses
  System.SysUtils,
  Chart4D.Consts,
  Chart4D.Plot,
  Chart4D.Renderer;

const
  ChartWidth = 640;
  ChartHeight = 450;

procedure TSegmentLabelTests.Setup;
begin
  FRecordingCanvas := TRecordingCanvas.Create;
  FCanvas := FRecordingCanvas;
end;

procedure TSegmentLabelTests.TearDown;
begin
  FCanvas := nil;
  FRecordingCanvas := nil;
end;

procedure TSegmentLabelTests.RenderPie(const Kind: TChartKind; const Categories: TArray<string>;
                                       const Values: TArray<Double>; const LabelBackground: TAlphaColor);
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := Kind;
    Plot.Categories := Categories;
    Plot.AddSeries('Share', Values);

    var Style := Plot.Style;
    Style.LabelBackgroundColor := LabelBackground;
    Plot.Style := Style;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);
  finally
    Plot.Free;
  end;
end;

function TSegmentLabelTests.SegmentLabelCall(const Text: string): TCanvasCall;
begin
  for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
  begin
    if Call.Text = Text then
      Exit(Call);
  end;

  Assert.Fail(Format('The segment label "%s" was not drawn', [Text]));
  Result := Default(TCanvasCall);
end;

/// <summary>
/// Renders a pie of three equal segments, far enough apart that no label collides, with the
/// given label mode and no legend, so any category name or share in the output comes from a
/// segment label. Returns the hit map.
/// </summary>
function TSegmentLabelTests.RenderThirds(const Mode: TSegmentLabelMode;
                                         const LabelBackground: TAlphaColor): TArray<TChartHitTarget>;
begin
  var Style := TChartStyle.Default;
  Style.LabelBackgroundColor := LabelBackground;
  Result := RenderThirdsWithStyle(Mode, Style);
end;

function TSegmentLabelTests.RenderThirdsWithStyle(const Mode: TSegmentLabelMode;
                                                  const Style: TChartStyle): TArray<TChartHitTarget>;
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.LegendPosition := TLegendPosition.None;
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('Share', [1, 1, 1]);
    Plot.SegmentLabels := Mode;
    Plot.Style := Style;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight, Result);
  finally
    Plot.Free;
  end;
end;

/// <summary>
/// Renders the three equal segments of <c>RenderThirds</c> in <c>Percentage</c> mode, with the
/// given segment label decimals and value axis options.
/// </summary>
procedure TSegmentLabelTests.RenderThirdsWithDecimals(const SegmentLabelDecimals: Integer;
                                                      const YAxis: TAxisOptions);
begin
  const Plot = TChartPlot.Create;
  try
    Plot.Kind := TChartKind.Pie;
    Plot.LegendPosition := TLegendPosition.None;
    Plot.Categories := ['A', 'B', 'C'];
    Plot.AddSeries('Share', [1, 1, 1]);
    Plot.SegmentLabels := TSegmentLabelMode.Percentage;
    Plot.SegmentLabelDecimals := SegmentLabelDecimals;
    Plot.YAxis := YAxis;

    TChartRenderer.Render(Plot, FCanvas, ChartWidth, ChartHeight);
  finally
    Plot.Free;
  end;
end;

/// <summary>
/// The default style with no label box, so each segment label's text sits straight on its
/// wedge, and the given minimum text contrast.
/// </summary>
function TSegmentLabelTests.BoxlessStyleWithMinimumContrast(const MinimumContrast: Double): TChartStyle;
begin
  Result := TChartStyle.Default;
  Result.LabelBackgroundColor := TAlphaColors.Null;
  Result.MinimumTextContrast := MinimumContrast;
end;

function TSegmentLabelTests.CountOfText(const Text: string): Integer;
begin
  Result := 0;
  for var Call in FRecordingCanvas.CallsOfKind(TCanvasCallKind.DrawText) do
  begin
    if Call.Text = Text then
      Inc(Result);
  end;
end;

function TSegmentLabelTests.LastCallIndexOfKind(const Kind: TCanvasCallKind): Integer;
begin
  Result := -1;
  for var Index := 0 to FRecordingCanvas.Calls.Count - 1 do
  begin
    if FRecordingCanvas.Calls[Index].Kind = Kind then
      Result := Index;
  end;
end;

/// <summary>
/// Asserts that no wedge comes after any segment label in the recorded calls, which is
/// the only order in which a wedge cannot paint over a label. Segment labels are the text
/// ending in a closing percentage, "Category (n%)"; the legend and donut centre text never do.
/// </summary>
procedure TSegmentLabelTests.AssertEveryLabelDrawnAfterTheLastWedge;
begin
  const LastWedge = LastCallIndexOfKind(TCanvasCallKind.FillPolygon);
  Assert.IsTrue(LastWedge >= 0, 'The chart must draw its wedges');

  var LabelCount := 0;
  for var Index := 0 to FRecordingCanvas.Calls.Count - 1 do
  begin
    const Call = FRecordingCanvas.Calls[Index];
    const IsSegmentLabel = (Call.Kind = TCanvasCallKind.DrawText) and Call.Text.EndsWith('%)');
    if not IsSegmentLabel then
      Continue;

    Inc(LabelCount);
    Assert.IsTrue(Index > LastWedge,
      Format('The label "%s" must be drawn after every wedge, or a later one covers it', [Call.Text]));
  end;

  Assert.IsTrue(LabelCount > 0, 'The chart must draw segment labels for this check to mean anything');
end;

procedure TSegmentLabelTests.PieChart_EveryLabel_IsDrawnAfterTheLastWedge;
begin
  { Wedges were drawn in category order with each label right after its own wedge, so the
    next wedge painted over it: a label near a boundary lost its first half, and the
    covered label still held its place, so a later, visible label could be dropped for
    colliding with one nobody could see. }
  RenderPie(TChartKind.Pie, ['Lopen', 'Fiets', 'Bus', 'Trein', 'Auto'], [18, 27, 0.2, 9, 45.8]);

  AssertEveryLabelDrawnAfterTheLastWedge;
end;

procedure TSegmentLabelTests.DonutChart_EveryLabel_IsDrawnAfterTheLastWedge;
begin
  RenderPie(TChartKind.Donut, ['Lopen', 'Fiets', 'Bus', 'Trein', 'Auto'], [18, 27, 0.2, 9, 45.8]);

  AssertEveryLabelDrawnAfterTheLastWedge;
end;

procedure TSegmentLabelTests.PieChart_SmallSegmentBeforeALargerOne_NeverDisplacesTheLargerLabel;
begin
  { A 1% and an 8% segment side by side at the top of the pie put their labels on top of
    each other, so one has to go. Offered in category order the 1% label came first and
    pushed out the 8% one; the larger segment is the one worth naming. }
  RenderPie(TChartKind.Pie, ['A', 'B', 'C'], [1, 8, 91]);

  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('B (8%)'), 'The 8% segment must keep its label');
  Assert.IsFalse(FRecordingCanvas.HasTextEqualTo('A (1%)'),
    'The 1% label collides with the 8% one, so it is the one to drop');
  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('C (91%)'), 'The largest segment is always labelled');
end;

procedure TSegmentLabelTests.PieChart_EqualSegmentsThatCollide_KeepTheEarlierCategory;
begin
  { Two equal segments have no size to choose between them, so category order decides and
    the same data always keeps the same label. }
  RenderPie(TChartKind.Pie, ['A', 'B', 'C'], [4, 4, 92]);

  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('A (4%)'), 'The earlier of two equal segments keeps its label');
  Assert.IsFalse(FRecordingCanvas.HasTextEqualTo('B (4%)'),
    'The later of two equal, colliding segments is the one dropped');
end;

procedure TSegmentLabelTests.SegmentLabels_CategoryAndPercentage_ShowsBoth;
begin
  RenderThirds(TSegmentLabelMode.CategoryAndPercentage);

  Assert.AreEqual(1, CountOfText('A (33%)'));
  Assert.AreEqual(1, CountOfText('B (33%)'));
  Assert.AreEqual(1, CountOfText('C (33%)'));
end;

procedure TSegmentLabelTests.SegmentLabels_Percentage_ShowsTheShareAlone;
begin
  { For a chart whose legend already names the categories, which is where the name in
    every label only repeats it. }
  RenderThirds(TSegmentLabelMode.Percentage);

  Assert.AreEqual(3, CountOfText('33%'), 'Every segment must be labelled with its share');
  Assert.AreEqual(0, CountOfText('A (33%)'), 'The category must not appear in a share-only label');
  Assert.AreEqual(0, CountOfText('A'), 'The category must not appear in a share-only label');
end;

procedure TSegmentLabelTests.SegmentLabels_Category_ShowsTheCategoryAlone;
begin
  RenderThirds(TSegmentLabelMode.Category);

  Assert.AreEqual(1, CountOfText('A'));
  Assert.AreEqual(1, CountOfText('B'));
  Assert.AreEqual(1, CountOfText('C'));
  Assert.AreEqual(0, CountOfText('33%'), 'The share must not appear in a category-only label');
end;

procedure TSegmentLabelTests.SegmentLabels_None_DrawsNoLabelsButKeepsTheHitTargets;
begin
  const HitMap = RenderThirds(TSegmentLabelMode.None);

  Assert.AreEqual(0, FRecordingCanvas.CountOfKind(TCanvasCallKind.DrawText),
    'Without a legend, title or labels, the pie draws no text at all');
  Assert.AreEqual(0, FRecordingCanvas.CountOfKind(TCanvasCallKind.FillRect),
    'No label means no label background box either');
  Assert.AreEqual(3, Length(HitMap), 'Hover must still find every segment when it carries no label');
end;

procedure TSegmentLabelTests.SegmentLabelDecimals_One_ShowsOneDecimal;
begin
  RenderThirdsWithDecimals(1, TAxisOptions.Default);

  Assert.AreEqual(3, CountOfText('33.3%'), 'Every segment must show its share at one decimal');
end;

procedure TSegmentLabelTests.SegmentLabelDecimals_Automatic_IgnoresTheValueAxisDecimals;
begin
  { A pie has no value axis on screen, so the decimals set on it must not reach the labels. }
  var YAxis := TAxisOptions.Default;
  YAxis.Decimals := 2;

  RenderThirdsWithDecimals(AutomaticDecimals, YAxis);

  Assert.AreEqual(3, CountOfText('33%'), 'The labels must stay whole percents');
end;

procedure TSegmentLabelTests.SegmentLabelDecimals_DutchValueAxisLocale_UsesCommaDecimalSeparator;
begin
  var YAxis := TAxisOptions.Default;
  YAxis.LocaleName := 'nl-NL';

  RenderThirdsWithDecimals(1, YAxis);

  Assert.AreEqual(3, CountOfText('33,3%'), 'The labels must follow the value axis locale');
end;

procedure TSegmentLabelTests.LabelBackground_Default_DrawsWhiteBoxesWithTheStyleTextColor;
begin
  { Without a legend the label boxes are the only rectangles a pie draws. }
  RenderThirds(TSegmentLabelMode.CategoryAndPercentage);

  Assert.AreEqual(3, FRecordingCanvas.CountOfColor(TCanvasCallKind.FillRect, ChartLabelBackground),
    'Every label keeps its opaque white box by default');
  for var Text in ['A (33%)', 'B (33%)', 'C (33%)'] do
  begin
    Assert.AreEqual<TAlphaColor>(ChartTextDark, SegmentLabelCall(Text).TextStyle.Color,
      Format('On a white box, "%s" keeps the style''s own text color', [Text]));
  end;
end;

procedure TSegmentLabelTests.LabelBackground_CustomOpaqueColor_FillsEveryLabelBox;
begin
  const Cream = TAlphaColor($FFFFF3C4);

  RenderThirds(TSegmentLabelMode.CategoryAndPercentage, Cream);

  Assert.AreEqual(3, FRecordingCanvas.CountOfColor(TCanvasCallKind.FillRect, Cream));
  Assert.AreEqual(0, FRecordingCanvas.CountOfColor(TCanvasCallKind.FillRect, ChartLabelBackground),
    'A custom box color replaces the white one rather than adding to it');
end;

procedure TSegmentLabelTests.LabelBackground_Transparent_DrawsTheTextWithoutABox;
begin
  RenderThirds(TSegmentLabelMode.CategoryAndPercentage, TAlphaColors.Null);

  Assert.AreEqual(0, FRecordingCanvas.CountOfKind(TCanvasCallKind.FillRect),
    'A fully transparent background draws no box at all');
  Assert.AreEqual(1, CountOfText('A (33%)'), 'The label text is still drawn');
  Assert.AreEqual(1, CountOfText('B (33%)'));
  Assert.AreEqual(1, CountOfText('C (33%)'));
end;

procedure TSegmentLabelTests.LabelBackground_Transparent_GivesEachLabelTextThatContrastsWithItsWedge;
begin
  { With no box the text sits straight on its wedge. The first three categories take the
    palette's blue, orange and dark red. On blue white contrasts about 4.5 to 1 against 3.5
    for the default dark text, on dark red 8.9 against 1.8, and on orange the dark text
    wins, 8.3 against 1.9. }
  RenderThirds(TSegmentLabelMode.CategoryAndPercentage, TAlphaColors.Null);

  Assert.AreEqual<TAlphaColor>(TAlphaColors.White, SegmentLabelCall('A (33%)').TextStyle.Color,
    'Text on the blue wedge must turn white');
  Assert.AreEqual<TAlphaColor>(ChartTextDark, SegmentLabelCall('B (33%)').TextStyle.Color,
    'Text on the orange wedge must keep the dark style color');
  Assert.AreEqual<TAlphaColor>(TAlphaColors.White, SegmentLabelCall('C (33%)').TextStyle.Color,
    'Text on the dark red wedge must turn white');
end;

procedure TSegmentLabelTests.LabelBackground_Transparent_StillDropsACollidingLabel;
begin
  { No box is drawn, but a label still claims the room its box would take, or two labels
    could land on top of each other with nothing to separate them. }
  RenderPie(TChartKind.Pie, ['A', 'B', 'C'], [1, 8, 91], TAlphaColors.Null);

  Assert.IsTrue(FRecordingCanvas.HasTextEqualTo('B (8%)'));
  Assert.IsFalse(FRecordingCanvas.HasTextEqualTo('A (1%)'),
    'Without a box the 1% label still collides with the 8% one and is dropped');
end;

procedure TSegmentLabelTests.MinimumTextContrast_Three_KeepsDarkTextOnTheBlueWedgeOnly;
begin
  { The dark text reaches about 3.5 to 1 on the blue wedge, enough at a minimum of 3, and
    only about 1.8 on the dark red one, where it still turns white. }
  RenderThirdsWithStyle(TSegmentLabelMode.CategoryAndPercentage, BoxlessStyleWithMinimumContrast(3));

  Assert.AreEqual<TAlphaColor>(ChartTextDark, SegmentLabelCall('A (33%)').TextStyle.Color,
    'At a minimum of 3 the dark text is legible enough on blue to keep');
  Assert.AreEqual<TAlphaColor>(ChartTextDark, SegmentLabelCall('B (33%)').TextStyle.Color);
  Assert.AreEqual<TAlphaColor>(TAlphaColors.White, SegmentLabelCall('C (33%)').TextStyle.Color,
    'Dark red is still too dark for the dark text');
end;

procedure TSegmentLabelTests.MinimumTextContrast_One_KeepsTheStyleTextColorOnEveryWedge;
begin
  RenderThirdsWithStyle(TSegmentLabelMode.CategoryAndPercentage, BoxlessStyleWithMinimumContrast(1));

  for var Text in ['A (33%)', 'B (33%)', 'C (33%)'] do
  begin
    Assert.AreEqual<TAlphaColor>(ChartTextDark, SegmentLabelCall(Text).TextStyle.Color,
      Format('A minimum of 1 keeps one text color throughout, so "%s" must stay dark', [Text]));
  end;
end;

procedure TSegmentLabelTests.TextContrast_CustomPalette_IsJudgedAgainstThePaletteColor;
begin
  { Chosen so every label comes out the other way from the default palette, where the blue
    and dark red labels turn white and the orange one stays dark: a pale yellow, a navy and a
    pale cyan give dark, white and dark instead. }
  var Style := BoxlessStyleWithMinimumContrast(4.5);
  Style.Palette := [TAlphaColor($FFFFF59D), TAlphaColor($FF1A237E), TAlphaColor($FFE0F7FA)];

  RenderThirdsWithStyle(TSegmentLabelMode.CategoryAndPercentage, Style);

  Assert.AreEqual<TAlphaColor>(ChartTextDark, SegmentLabelCall('A (33%)').TextStyle.Color,
    'Text on the pale yellow wedge must stay dark');
  Assert.AreEqual<TAlphaColor>(TAlphaColors.White, SegmentLabelCall('B (33%)').TextStyle.Color,
    'Text on the navy wedge must turn white');
  Assert.AreEqual<TAlphaColor>(ChartTextDark, SegmentLabelCall('C (33%)').TextStyle.Color,
    'Text on the pale cyan wedge must stay dark');
end;

end.
