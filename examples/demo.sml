(* demo.sml - build a small UTXO set from a fixed coinbase, spend it, and report
   transaction ids, set sizes, and output values. Deterministic: same output on
   every run and compiler (fixed transactions, integer/txid output only). *)

fun showVal (v : IntInf.int) = IntInf.toString v

fun coinbase txidStr value script =
  { version  = 0w1
  , inputs   = []
  , outputs  = [{value = IntInf.fromInt value, scriptPubKey = script}]
  , locktime = 0w0 }

fun spend prevTxid prevIdx value script =
  { version  = 0w1
  , inputs   = [{ prevout   = {txid = prevTxid, index = prevIdx}
                , scriptSig = ""
                , sequence  = 0wxFFFFFFFF }]
  , outputs  = [{value = IntInf.fromInt value, scriptPubKey = script}]
  , locktime = 0w0 }

val u0 = Utxo.empty ()

(* Coinbase creates one new output worth 5000. *)
val cb = coinbase "genesis" 5000 "p2pk"
val u1 = Utxo.apply u0 cb
val cbId = Utxo.txid cb
val () = print "Coinbase transaction:\n"
val () = print ("  txid = " ^ cbId ^ "\n")
val () = print ("  utxo set size = " ^ Int.toString (Utxo.size u1) ^ "\n")
val () = print ("  output 0 value = "
                ^ (case Utxo.lookup u1 {txid = cbId, index = 0}
                     of SOME o' => showVal (#value o') | NONE => "<missing>") ^ "\n")

(* Spend the coinbase output, creating a new 4000 output. *)
val sp = spend cbId 0 4000 "p2pk2"
val u2 = Utxo.apply u1 sp
val spId = Utxo.txid sp
val () = print "\nSpend transaction:\n"
val () = print ("  txid = " ^ spId ^ "\n")
val () = print ("  utxo set size = " ^ Int.toString (Utxo.size u2) ^ "\n")
val () = print ("  coinbase output spent = "
                ^ Bool.toString (not (Option.isSome (Utxo.lookup u2 {txid = cbId, index = 0}))) ^ "\n")
val () = print ("  new output 0 value = "
                ^ (case Utxo.lookup u2 {txid = spId, index = 0}
                     of SOME o' => showVal (#value o') | NONE => "<missing>") ^ "\n")

(* A double-spend of the already-consumed coinbase output is rejected. *)
val () = print "\nDouble-spend attempt of the spent coinbase output:\n"
val () = print ("  result = "
                ^ ((Utxo.apply u2 (spend cbId 0 1000 "p2pk3"); "accepted (unexpected)")
                   handle Utxo.DoubleSpend => "rejected (DoubleSpend)") ^ "\n")
