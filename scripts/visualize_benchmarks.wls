#!/usr/bin/env wolframscript
(* ZK-Matrix Join Benchmark Visualization *)

dataNaive = {{1000, 71437296}, {5000, 450271496}, {10000, 893025827}};
dataOptimized = {{1000, 2145908}, {5000, 10657944}, {10000, 21299845}};

plot = ListLogPlot[
  {dataNaive, dataOptimized},
  Joined -> True,
  Mesh -> All,
  PlotStyle -> {
    {Red, Thickness[0.008], Dashed},
    {Darker[Green], Thickness[0.01]}
  },
  PlotLegends -> PointLegend[
    {Red, Darker[Green]},
    {"Naive (Standard Ruma)", "Optimized (Topological Coprocessor)"},
    LegendMarkerSize -> 20
  ],
  Frame -> True,
  FrameLabel -> {"Matrix Events", "RISC-V CPU Cycles (Log Scale)"},
  PlotLabel -> Style["ZK-Matrix Join: Scaling Performance (Real Data)", Bold, 16],
  GridLines -> Automatic,
  ImageSize -> 800,
  Epilog -> {
    Inset[
      Framed[
        Column[{
          Style["Speedup at 10k: 41.9x", Bold, Darker[Green]],
          Style["Cycles Reduced by 871M", Bold, Darker[Green]]
        }],
        Background -> White, RoundingRadius -> 5
      ],
      {7500, 5*10^7}
    ]
  }
];

Export["res/benchmark_visualization.png", plot];
Print["Visualization exported to res/benchmark_visualization.png"];
