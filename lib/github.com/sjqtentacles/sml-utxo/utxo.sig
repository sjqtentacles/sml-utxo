signature UTXO =
sig
  type txid = string
  type outpoint = { txid : txid, index : int }
  type txout = { value : IntInf.int, scriptPubKey : string }
  type txin  = { prevout : outpoint, scriptSig : string, sequence : Word32.word }
  type tx = { version  : Word32.word
            , inputs   : txin list
            , outputs  : txout list
            , locktime : Word32.word }

  exception DoubleSpend
  exception Overspend
  exception InvalidTx

  type utxo

  val empty  : unit -> utxo
  val lookup : utxo -> outpoint -> txout option
  val size   : utxo -> int
  val apply  : utxo -> tx -> utxo
  val txid   : tx -> txid
end
