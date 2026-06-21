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
            end)
      end
    end
end
