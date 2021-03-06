%% Doesn't check matrix sizes match but 
%% not restricted to square matrices.
%%
%% Taking P as a perfect square.
%% 
%% Represent matrix as a list.
%% Doesn't use destructive assignment so building a
%% matrix creates an awful lot of temporary lists.
%%

-module(nodemat). 
-export([reverse_create/1, start/0, printMat/4, multiply/9, multiplyRC/10, multserver/0,
 cijmultserver/0, domultiply/7, startmultserver/0, startcijmultserver/0, getSubMatrix/9,
addMatrix/6, getCElement/13, getCIJ/11, runDistMatmul/12, getRowK/11, init_clear/6, fin_done/0]). 
-import(lists, [reverse/1, nth/2]).
-import(math, [sqrt/1]).

printMat(M,R,C,X) -> 
    io:fwrite("~w ", [nth(X,M)]),
   if 
      (X rem R == 0) and (C*R /= X) -> 
         io:fwrite("~n"),
         printMat(M,R,C,X+1);
    (X rem R == 0) and (C*R == X) ->
        io:fwrite("~n~n"),
        ok;
      true -> 
        printMat(M,R,C,X+1)
   end.

multiply(M1,M2,R1,R2,C1,C2,MM, X,Y) ->
   if 
      (X == R1 + 1) ->
        reverse(MM);
      (Y == C2 + 1) -> 
         multiply(M1,M2,R1,R2,C1,C2, MM, X+1,1);
      true -> 
         Out = multiplyRC(M1,M2,R1,R2,C1,C2, X, Y, 1, 0),
         multiply(M1,M2,R1,R2,C1,C2,[Out|MM], X,Y+1)
   end.

multiplyRC(M1,M2,R1,R2,C1,C2, X,Y,C, Sum) ->
   if 
      (C == C1 + 1) -> 
         Sum;
      true -> 
        multiplyRC(M1,M2,R1,R2,C1,C2, X,Y,C+1, Sum+nth((X-1)*C2+C,M1)*nth((C-1)*C2+Y,M2))
   end.    

multserver() ->
  receive 
    {From, {M1,M2,R1,R2,C1,C2}} ->
      Aut = multiply(M1,M2,R1,R2,C1,C2, [], 1,1),
      From ! {self(),Aut, node()},
      multserver();
    {From, done} ->
      From ! {self(),"Closed Mult Server"};
      _ -> 
      io:format("Unexpected Message!"),
      multserver()
    end.

domultiply(Pid, M1,M2,R1,R2,C1,C2) ->
  Pid ! {self(), {M1,M2,R1,R2,C1,C2}},
  receive 
    {Pid, Msg, FromNode} -> {Msg, FromNode}
    % add delay here
  end.

getCIJ(Pid, BPid, M1,M2,R1,R2,C1,C2, P, I, J) ->
  Pid ! {self(), {M1,M2,R1,R2,C1, C2, P, I, J}},
  receive 
    {Pid, Msg, FromNode} -> 
    io:fwrite("SubMatrix (~w,~w) - ~w from ~w~n",[I,J,Msg, FromNode]),
    {ok, S} = file:open("output.txt", [append]),
    io:format(S,"(~w,~w) - ~w~n",[I,J,Msg]),
    file:close(S)
    % add delay here
  after 6000 ->
    io:fwrite("timeout from ~w~nUsing Backup ~w~n",[Pid,BPid]),
    getRowK(BPid,BPid, M1,M2,R1,R2,C1,C2, P, I, J)
  end.

getRowK(Pid, BPid, M1,M2,R1,R2,C1,C2, P, X, Y) ->
    Max = round(sqrt(P)),
    if
      (Y == Max + 1) ->
        ok; 
    true ->
      io:fwrite("~w , ~w and ~w~n", [Pid,X,Y]),
      getCIJ(Pid,BPid, M1,M2,R1,R2,C1,C2, P, X, Y),
      getRowK(Pid,BPid, M1,M2,R1,R2,C1,C2, P, X, Y+1)
  end.

cijmultserver() ->
  receive 
    {From, {M1,M2,R1,R2,C1,C2, P, I, J}} ->
      KL = round(sqrt(P)),
      N = round(R1/sqrt(P)),   
      Sum = reverse_create(N*N),
      timer:sleep(5000),
      Aut = getCElement(M1,M2, R1, C1, R2, C2, KL, N, P, I, J, 0, Sum),
      From ! {self(),Aut, node()},
      cijmultserver();
    {From, done} ->
      From ! {self(),"Closed CIJ Mult Server"};
      _ -> 
      io:format("Unexpected Message!"),
      cijmultserver()
    end.


getSubMatrix(M, R, C, I, J, P, X, Y, SM) -> % assume I = J, P = no. of Processors
  N = round(R/sqrt(P)),
  % XL = (I-1)*N,
  XR = (I)*N-1,
  YL = (J-1)*N,
  YR = (J)*N-1,     
     if 
        (X == XR + 1) ->
          reverse(SM);
        (Y > YR) ->
           getSubMatrix(M, R, C, I, J, P, X+1, YL, SM);       
        true -> 
           A = nth(round(X)*C+round(Y)+1,M),
           getSubMatrix(M, R, C, I, J, P, X, Y+1, [A|SM])
     end.

startmultserver() ->
  spawn(?MODULE, multserver, []).

startcijmultserver() ->
  spawn(?MODULE, cijmultserver, []).

addMatrix(M1,M2,C,R,X,SM) ->
   RM = [nth(X,M1) + nth(X,M2) | SM],
   if 
      (X rem R == 0) and (C*R /= X) -> 
         addMatrix(M1,M2,C,R,X+1,RM);
    (X rem R == 0) and (C*R == X) ->
        reverse(RM);
      true -> 
        addMatrix(M1,M2,C,R,X+1,RM)
   end.

% do  contention-free formula here
getCElement(M1,M2, R1, C1, R2, C2, KL, N, P, I1, J1, K, Sum) -> % assume I = J, P = no. of Processors
     I = I1 - 1,
     J = J1 - 1,
     if 
        (K == KL) ->
          Sum;       
        true -> 
           R = I + 1,
           S = ((I+J+K) rem KL) + 1,
           A = getSubMatrix(M1, R1, C1, R, S, P, (R-1)*N, (S-1)*N , []),
           S1 = J + 1,
           B = getSubMatrix(M2, R2, C2, S, S1, P, (S-1)*N, (S1-1)*N , []),
           MultAB = multiply(A,B,N,N,N,N,[], 1,1),
           Net = addMatrix(Sum,MultAB, N,N,1, []),
           getCElement(M1,M2,R1,C1,R2,C2, KL, N, P, I1, J1, K+1, Net)           
     end.

reverse_create( 0 ) -> [];
reverse_create( N ) when N > 0 -> reverse_create( N-1 ) ++ [0].
  
start() ->
    R1 = 8,
    C1 = 8,
    R2 = 8,
    C2 = 8,
    P = 4,    
    M1 = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64],
    M2 = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64],
    printMat(M1,R1,C1,1),

    KL = round(sqrt(P)),
    N = round(R1/sqrt(P)),   
    Sum = reverse_create(N*N),

    Aut = getCElement(M1,M2, R1, C1, R2, C2, KL, N, P, 1, 1, 0, Sum),
    printMat(Aut,N,N,1),

    Aut1 = getCElement(M1,M2, R1, C1, R2, C2, KL, N, P, 1, 2, 0, Sum),
    printMat(Aut1,N,N,1),

    Aut2 = getCElement(M1,M2, R1, C1, R2, C2, KL, N, P, 2, 1, 0, Sum),
    printMat(Aut2,N,N,1),

    Aut3 = getCElement(M1,M2, R1, C1, R2, C2, KL, N, P, 2, 2, 0, Sum),
    printMat(Aut3,N,N,1),

    NAut = multiply(M1,M2,R1,R2,C1,C2, [], 1,1),
    printMat(NAut,R1,C1,1).

    % halt(0).   

init_clear(R1,R2,C1,C2,P, Nodes) ->
    L = length(Nodes),
    {ok, S} = file:open("output.txt", write),
    io:format(S,"-- Generated from Erlang --~n",[]),
    io:format(S,"~wX~w~n",[R1,C1]),
    io:format(S,"~wX~w~n",[L,P]),
    file:close(S).

fin_done() ->
  os:cmd("python parse.py"),
  {C,D} = file:consult("erlin.txt"),
  T = lists:nth(1,D),
  printMat(T,8,8,1).

runDistMatmul(M1,M2,R1,R2,C1,C2, P, Nodes, Procs, BProcs, X, Z) ->
    L = length(Nodes),
    Max = round(sqrt(P)),
    if
      (X == Max + 1) ->
        io:fwrite("Done~n"),
        ok;
      true ->
        io:fwrite("~w , ~w row~n", [Z,X]),
        spawn(?MODULE, getRowK, [nth(Z+1,Procs), nth(Z+1,BProcs) , M1,M2,R1,R2,C1,C2, P, X, 1]),
        runDistMatmul(M1,M2,R1,R2,C1,C2, P, Nodes, Procs,BProcs, X+1, (Z+1) rem L)
    end.
