(* ::Package:: *)

profParse[Content_String]:=Module[{r=Content},
    r=StringCases[r,RegularExpression["(\\d+)/[0-9.e+-]+\\s+(\\w+\\(\\) - .*)"]->("$2"->"$1")];
    ReadList[StringToStream[#],Real][[1]]&/@Association[r]
];
profParse::usage="read profiling out file";

$LD$LIBRARY$PATH=Environment["LD_LIBRARY_PATH"]/.$Failed->"";
SetEnvironment["LD_LIBRARY_PATH"->$LD$LIBRARY$PATH<>":"<>Environment["HOME"]<>"/.local/usr/lib:/usr/local/lib"];
SetEnvironment["PATH"->Environment["PATH"]<>":/usr/local/bin"];

Options[llvmProf]={MpiSize->"",PrintCmd->False};
$llvmProfExecute=StringTemplate["export MPI_SIZE=`1`\n llvm-prof `2`\n exit\n"];
llvmProf[para__,OptionsPattern[]]:=Module[{r,script},
  script=$llvmProfExecute[OptionValue[MpiSize],StringJoin[Riffle[{para}," "]]];
  If[OptionValue[PrintCmd],Print[script]];
  r=RunProcess[$SystemShell,All,script];
  If[r["ExitCode"]!=0,
    Message[llvmProf::fail,r["StandardError"]]
  ];
  r["StandardOutput"]
]
llvmProf::usage="execute llvm-prof and obtain output";
llvmProf::fail="execute failed `1`";

readTiming[x_,field_]:=StringCases[x,StartOfLine~~field~~": "~~y:NumberString~~"e+"~~r:DigitCharacter..->y~~"*10^("~~r~~"-09)"]//First//ToExpression
readTiming::usage="read timing value from llvm-prof timing mode output";

filesRead[patt_String]:=Import[#,"Text"]&/@FileNames[patt]
filesRead::usage="read multi files with pattern";

$dynamicTrans[{x_,y_},{n_,m_}]:={Clip[Floor[n-y]+1,{1,n}],Clip[Floor@x+1,{1,m}]};
Options[dynamicDiffVisual]={Scaling->True};
dynamicDiffVisual[base_Association,b_Association,OptionsPattern[]]:=Module[{$,commK},
  commK=Sort[KeyTake[base,Keys[b]],Greater]//Keys;
  $=Floor[Sqrt[Length[commK]]];
  $=ArrayReshape[base/@commK-b/@commK,{$,$}];
  With[{$len=Length[$],$t=$dynamicTrans,$commK=commK},
    DynamicModule[{pt={1,1}/2,ij,key},
      Column@{
        LocatorPane[Dynamic[pt],If[OptionValue[Scaling],MatrixPlot,ArrayPlot][$,ImageSize->Medium,PlotTheme->"Detailed"]],
        Dynamic[(ij=$t[pt,{$len,$len}])->{key=$commK[[Plus@@(ij*{$len,1})-$len]],base[key],b[key]}]
      }
      ,SaveDefinitions->True
    ]
  ]
];
dynamicDiffVisual::usage="produce a dynamic module to display difference between a and b.";
(*
staticDiffVisual[base_Association,b__Association,o___]:=Module[{commK,len},
  commK=Sort[KeyTake[base,Intersection@@Keys/@{b}],Greater]//Keys;
  len=Floor[Sqrt[Length[commK]]];
  Extract[
    Table[MatrixPlot[ArrayReshape[i/@commK,{len,len}], ColorFunctionScaling->False, PlotLegends->Automatic, o],{i,{base,b}}],
  {{1,1},{2,1},{1,2,1},{2,2,1}}]
]
*)
LogarithmicScaling[x_, max_] := Log[x+1]/Log[max+1]
staticDiffVisual[base_Association, b__Association, o__]:=Module[{commK,len,max, ticksNum=6},
  commK=Sort[First@KeyUnion[{base,b}],Greater]//Keys;
  max=Max[{base,b}];
  len=Ceiling[Sqrt[Length[commK]]];
  Append[Table[MatrixPlot[ArrayReshape[i/@commK,{len,len},0],
    o,
    ColorFunctionScaling->False,
    ColorFunction->(GrayLevel[1-LogarithmicScaling[#,max]]&)
  ], {i,{base,b}}],
  BarLegend[{GrayLevel[1-#]&,{0,1}}, Ticks->({LogarithmicScaling[#,max],ScientificForm[#,2]}&/@(max^(Range[ticksNum]/ticksNum)))]
  ]
]
staticDiffVisual::usage="produce two graph to display difference between a and b. b is ordered";

(*http://www.ruanyifeng.com/blog/2013/03/cosine_similarity.html*)
CosDiff[A_,B_]:=Module[{C},
  C=Keys[A]\[Intersection]Keys[B];
  VectorAngle[A/@C/.x_Missing->0,B/@C/.x_Missing->0]
]

standardError[data_]:=StandardDeviation[data]/Sqrt[Length[data]]
standardError::usage="计算标准误差 (https://reference.wolfram.com/language/howto/AddErrorBarsToChartsAndPlots.html)";

minMaxError[data_]:={Min[data],Max[data]} - Mean[data]

Options[makeErrorBar]={ErrorFunction->standardError};
makeErrorBar[a_, OptionsPattern[]]:=Module[{t},
  t=Map[{Median[#],ErrorBar[OptionValue[ErrorFunction][#]]}&,a,{2}];
  Merge[{Keys/@t,Values/@t},Transpose]/.{x_,{y_,z_}}->{{x,y},z}
]
makeErrorBar::usage="convert cgpopReadMacroTiming's result suite for ErrorListPlot";

makeFullList[data_]:=Module[{a},
 a=Flatten[#, 1] & /@ 
 Map[Partition[Riffle[Sequence @@ #, {1, -2, 2}], 2] &, 
 Merge[{Values /@ data, Keys /@ data}, Transpose], {2}];
 a/.{x_,y_}:>{x+RandomReal[{-2,2}],y}/;NumberQ[x]
]
makeFullList::usage = "convert result assaultion suite for list plot";

errorBarPlotRange[data_]:=Max@(Last/@First/@data+Last/@Last/@data)
errorBarPlotRange::usage = "set PlotRange->All for ErrorListPlot";

rel1stError[a_, b_]:= (a-b)/a
rel2ndError[a_, b_]:= (a-b)/b
simpleError[a_, b_]:= b/a

Options[relError]={Label->None,ShowBase->False,ErrorFunction->rel1stError};
relError[base_,top__,OptionsPattern[]]:=Module[{$,comm},
  $=KeyIntersection[{base,top}/.{x_?NumberQ,y_?NumberQ}->(x->y)];
  $=KeySort/@$;
  comm=First[$];
  $=Rest[$];
  $=Table[OptionValue[ErrorFunction][i, comm],{i,$}];
  TableForm[Values@If[OptionValue[ShowBase],
      Prepend[$*100,comm],
      $*100
    ],TableHeadings->{OptionValue[Label], Keys[comm]}
  ]
]
relError::usage="计算相对误差";

predCost[real_, pred_, wall_, p_]:=(1-Abs[rel1stError[real,pred]])/(wall/(real*p))
predCostTable[real_, pred_, wall_]:=Riffle[Keys[real] ,
 Table[i -> predCost[real[j][i], pred[j][i], wall[j][i], i], {j, 
   Keys[real]}, {i, Keys[real[j]]}]
 ]

exportGraphics[g_List]:=Do[Export["/tmp/graph"<>ToString[i]<>".pdf",g[[i]]],{i,Length[g]}];

rasterTrick[plot_] := 
 Show[plot, 
  Prolog -> {Opacity[0], Texture[{{{0, 0, 0, 0}}}], 
    VertexTextureCoordinates -> {{0, 0}, {1, 0}, {1, 1}}, 
    Polygon[{{0, 0}, {.1, 0}, {.1, .1}}]}]

(*BasicGraph*)
$gTriangle=Graphics[{JoinedCurve[Line[{Offset[{0, 4}], Offset[{-2*Sqrt[3], -2}], Offset[{2*Sqrt[3], -2}], Offset[{0, 4}]}], CurveClosed -> True]}];
$gDiamond=Graphics[{AbsoluteThickness[1], Line[{Offset[{0, 3.75}], Offset[{3.75, 0}], Offset[{0, -3.75}], Offset[{-3.75, 0}], Offset[{0, 3.75}]}]}];






getMean[table_] :=
 Module[{$, min, max},
  min = Min@table;
  max = Max@table;
  $ = (Sum[table[[i]], {i, 1, Length[table]}] - min - 
      max)/(Length[table] - 2)
  ]
getInstNumber[bcfile_, profile_] :=
 Module[{$},
  $ = Flatten@
    StringCases[llvmProf[bcfile, profile, "-inst-number"], 
     "Inst number:\t" ~~ x : NumberString ~~ "e+" ~~ 
       y : NumberString ~~ "\n" -> {x, y}];
  $ = ToExpression[ToExpression[$[[1]]]*10^ToExpression[$[[2]]]]
  ]
getMPIFunctionMinTime[bcfile_, profilefile_, procesNum_, ite_] :=
 
 Module[{$, keys},
  $ = Table[
    Table[Association@
      StringCases[
       llvmProf[bcfile, 
        profilefile <> ToString[procesNum[[i]]] <> "/" <> 
         ToString[procesNum[[i]]] <> "." <> ToString[j] <> ".out*"], 
       x : NumberString ~~ ".\t" ~~ y : NumberString ~~ "\t" ~~ 
         z : (WordCharacter | "_") .. ~~ "_\t" ~~ w : NumberString ~~ 
         "\t" ~~ a : (WordCharacter | "_" | ":" | "\"") .. -> (a ~~ 
           "_" ~~ z ~~ "_:" ~~ w -> ToExpression[y])], {j, 0, 
      ite - 1}], {i, 1, Length[procesNum]}];
  keys = Keys[$[[1]]][[1]];
  $ = Table[
    Association@
     Table[keys[[i]] -> 
       getMean@Table[
         ToExpression[$[[k]][[j]][keys[[i]]]], {j, 1, ite}], {i, 1, 
       Length[keys]}], {k, 1, Length[procesNum]}];
  $ = Association@
    Table[keys[[i]] -> 
      Table[{procesNum[[j]], $[[j]][keys[[i]]]}, {j, 1, 
        Length[procesNum]}], {i, 1, Length[keys]}]
  ]
getModel[trainmpitimetable_] := 
 Module[{iSet, jSet, onece, funcFits, funcNormals, r2s, maxR2, 
   maxFunc, test}, iSet = {-6/2, -5/2, -4/2, -3/2, -2/2, -1/2, 0};
  jSet = {0, 1/4, 2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 8/4};
  onece = Flatten@Table[a*(x^i)*(Log2[x]^j), {i, iSet}, {j, jSet}];
  funcFits = 
   Table[NonlinearModelFit[trainmpitimetable, i, {a}, x], {i, 
     onece}];
  funcNormals = Table[Normal[i], {i, funcFits}];
  r2s = Table[i["RSquared"], {i, funcFits}];
  maxR2 = Max@r2s;
  maxFunc = Evaluate[funcNormals[[Ordering[r2s, 1, Greater]]][[1]]];
  test = Function[{x}, maxFunc]]
