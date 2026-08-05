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
unit Chart4D.Mapper.Tests;

/// <summary>
/// Tests for <c>TLinearMapper</c>: endpoint, midpoint, and inverted mapping.
/// </summary>

interface

uses
  DUnitX.TestFramework,
  Chart4D.Axis;

type
  [TestFixture]
  TLinearMapperTests = class
  public
    [Test]
    procedure Map_DataMin_ReturnsPixelMin;

    [Test]
    procedure Map_DataMax_ReturnsPixelMax;

    [Test]
    procedure Map_Midpoint_ReturnsPixelMidpoint;

    [Test]
    procedure Map_Inverted_SwapsPixelRange;

    [Test]
    procedure Map_ZeroDataRange_ReturnsPixelMin;
  end;

implementation

procedure TLinearMapperTests.Map_DataMin_ReturnsPixelMin;
begin
  const Mapper = TLinearMapper.Create(0, 100, 10, 210, False);

  const Actual = Mapper.Map(0);

  Assert.AreEqual<Single>(10, Actual);
end;

procedure TLinearMapperTests.Map_DataMax_ReturnsPixelMax;
begin
  const Mapper = TLinearMapper.Create(0, 100, 10, 210, False);

  const Actual = Mapper.Map(100);

  Assert.AreEqual<Single>(210, Actual);
end;

procedure TLinearMapperTests.Map_Midpoint_ReturnsPixelMidpoint;
begin
  const Mapper = TLinearMapper.Create(0, 100, 10, 210, False);

  const Actual = Mapper.Map(50);

  Assert.AreEqual<Single>(110, Actual);
end;

procedure TLinearMapperTests.Map_Inverted_SwapsPixelRange;
begin
  const Mapper = TLinearMapper.Create(0, 100, 10, 210, True);

  const ActualAtDataMin = Mapper.Map(0);
  const ActualAtDataMax = Mapper.Map(100);

  Assert.AreEqual<Single>(210, ActualAtDataMin);
  Assert.AreEqual<Single>(10, ActualAtDataMax);
end;

procedure TLinearMapperTests.Map_ZeroDataRange_ReturnsPixelMin;
begin
  const Mapper = TLinearMapper.Create(50, 50, 10, 210, False);

  const Actual = Mapper.Map(50);

  Assert.AreEqual<Single>(10, Actual);
end;

end.
