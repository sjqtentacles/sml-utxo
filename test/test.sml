structure UtxoTests =
struct
  fun makeCoinbase txidStr value script =
    { version  = 0w1
    , inputs   = []
    , outputs  = [{value = IntInf.fromInt value, scriptPubKey = script}]
    , locktime = 0w0
    }

  fun makeSpend prevTxid prevIdx value script =
    { version  = 0w1
    , inputs   = [{ prevout   = {txid = prevTxid, index = prevIdx}
                  , scriptSig = ""
                  , sequence  = 0wxFFFFFFFF }]
    , outputs  = [{value = IntInf.fromInt value, scriptPubKey = script}]
    , locktime = 0w0
    }

  (* a tx spending one input but producing two outputs *)
  fun makeSpend2 prevTxid prevIdx (v1, s1) (v2, s2) =
    { version  = 0w1
    , inputs   = [{ prevout   = {txid = prevTxid, index = prevIdx}
                  , scriptSig = ""
                  , sequence  = 0wxFFFFFFFF }]
    , outputs  = [ {value = IntInf.fromInt v1, scriptPubKey = s1}
                 , {value = IntInf.fromInt v2, scriptPubKey = s2} ]
    , locktime = 0w0
    }

  val ii = IntInf.fromInt

  fun run () =
    let
      val u0 = Utxo.empty ()
    in
      Harness.section "UTXO coinbase";

      let
        val cb = makeCoinbase "genesis" 5000 "p2pk"
        val u1 = Utxo.apply u0 cb
        val cbTxid = Utxo.txid cb
      in
        Harness.checkInt "size after coinbase" (1, Utxo.size u1);
        Harness.check "lookup output 0 exists"
          (Option.isSome (Utxo.lookup u1 {txid = cbTxid, index = 0}));

        Harness.section "UTXO spend";
        let
          val spendTx = makeSpend cbTxid 0 4000 "p2pk2"
          val u2 = Utxo.apply u1 spendTx
          val spendTxid = Utxo.txid spendTx
        in
          Harness.checkInt "size after spend" (1, Utxo.size u2);
          Harness.check "old output spent" (not (Option.isSome (Utxo.lookup u2 {txid = cbTxid, index = 0})));
          Harness.check "new output created" (Option.isSome (Utxo.lookup u2 {txid = spendTxid, index = 0}));

          Harness.section "UTXO double spend";
          Harness.checkRaises "double spend raises"
            (fn () => Utxo.apply u2 (makeSpend cbTxid 0 1000 "p2pk3"))
        end;

        Harness.section "UTXO overspend";
        Harness.checkRaises "overspend raises"
          (fn () =>
            let
              val cb2 = makeCoinbase "genesis2" 1000 "p2pk"
              val u3 = Utxo.apply u0 cb2
              val cb2Txid = Utxo.txid cb2
              val overspend = { version  = 0w1
                              , inputs   = [{ prevout   = {txid = cb2Txid, index = 0}
                                            , scriptSig = ""
                                            , sequence  = 0wxFFFFFFFF }]
                              , outputs  = [{value = IntInf.fromInt 2000, scriptPubKey = "x"}]
                              , locktime = 0w0 }
            in
              Utxo.apply u3 overspend
            end);

        Harness.section "multi-output spend + fee + balance";
        let
          val cb = makeCoinbase "fund" 10000 "alice"
          val u1 = Utxo.apply u0 cb
          val cbId = Utxo.txid cb
          (* spend 10000 -> 6000 to bob + 3500 to alice (change); fee = 500 *)
          val spend = makeSpend2 cbId 0 (6000, "bob") (3500, "alice")
          val theFee = Utxo.fee u1 spend
          val u2 = Utxo.apply u1 spend
          val spId = Utxo.txid spend
        in
          Harness.check "fee = 500" (IntInf.compare (theFee, ii 500) = EQUAL);
          Harness.checkInt "two outputs created" (2, Utxo.size u2);
          Harness.check "output 0 exists" (Utxo.member u2 {txid = spId, index = 0});
          Harness.check "output 1 exists" (Utxo.member u2 {txid = spId, index = 1});
          Harness.check "total value 9500" (IntInf.compare (Utxo.totalValue u2, ii 9500) = EQUAL);
          Harness.check "balance to alice = 3500"
            (IntInf.compare (Utxo.balance u2 (fn s => s = "alice"), ii 3500) = EQUAL);
          Harness.check "balance to bob = 6000"
            (IntInf.compare (Utxo.balance u2 (fn s => s = "bob"), ii 6000) = EQUAL)
        end;

        Harness.section "zero fee";
        let
          val cb = makeCoinbase "z" 1000 "x"
          val u1 = Utxo.apply u0 cb
          val sp = makeSpend (Utxo.txid cb) 0 1000 "y"
        in
          Harness.check "fee = 0" (IntInf.compare (Utxo.fee u1 sp, ii 0) = EQUAL);
          Harness.check "coinbase fee = 0" (IntInf.compare (Utxo.fee u0 cb, ii 0) = EQUAL)
        end;

        Harness.section "applyBlock";
        let
          val cb = makeCoinbase "blk" 5000 "m"
          val sp = makeSpend (Utxo.txid cb) 0 4000 "n"
          val uB = Utxo.applyBlock u0 [cb, sp]
        in
          Harness.checkInt "block applied -> 1 utxo" (1, Utxo.size uB);
          Harness.check "spent output gone"
            (not (Utxo.member uB {txid = Utxo.txid cb, index = 0}));
          (* tryApplyBlock with a bad tx fails cleanly *)
          Harness.check "tryApplyBlock bad -> NONE"
            (not (Option.isSome (Utxo.tryApplyBlock u0 [sp])))   (* sp spends a non-existent output *)
        end;

        Harness.section "InvalidTx validation";
        let
          val noOut = { version = 0w1, inputs = [], outputs = [], locktime = 0w0 }
          val zeroVal = makeCoinbase "v" 0 "x"   (* value 0 -> non-positive *)
          val cb = makeCoinbase "d" 100 "x"
          val cbId = Utxo.txid cb
          val dupIn = { version = 0w1
                      , inputs = [ { prevout = {txid=cbId,index=0}, scriptSig="", sequence=0wxFFFFFFFF }
                                 , { prevout = {txid=cbId,index=0}, scriptSig="", sequence=0wxFFFFFFFF } ]
                      , outputs = [{value = ii 50, scriptPubKey = "y"}]
                      , locktime = 0w0 }
        in
          Harness.checkRaises "empty outputs raises" (fn () => Utxo.apply u0 noOut);
          Harness.checkRaises "zero output value raises" (fn () => Utxo.apply u0 zeroVal);
          Harness.checkRaises "duplicate input raises" (fn () => Utxo.validate dupIn);
          Harness.check "tryApply invalid -> NONE" (not (Option.isSome (Utxo.tryApply u0 noOut)))
        end;

        Harness.section "txid determinism + non-collision";
        let
          val a = makeCoinbase "t" 100 "alice"
          val b = makeCoinbase "t" 100 "alice"          (* identical -> same id *)
          val c = makeCoinbase "t" 100 "bob"            (* differs only by scriptPubKey *)
        in
          Harness.check "identical txs -> same id" (Utxo.txid a = Utxo.txid b);
          Harness.check "scriptPubKey changes id" (Utxo.txid a <> Utxo.txid c)
        end
      end
    end
end
