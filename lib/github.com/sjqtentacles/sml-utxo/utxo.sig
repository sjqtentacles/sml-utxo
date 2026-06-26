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
  exception InvalidTx of string

  type utxo

  (* ---- construction / queries ---- *)
  val empty       : unit -> utxo
  val lookup      : utxo -> outpoint -> txout option
  val member      : utxo -> outpoint -> bool
  val size        : utxo -> int
  val toList      : utxo -> (outpoint * txout) list
  val outpointsOf : utxo -> outpoint list
  (* total satoshi value held in the set *)
  val totalValue  : utxo -> IntInf.int
  (* total value of unspent outputs whose scriptPubKey matches the predicate *)
  val balance     : utxo -> (string -> bool) -> IntInf.int

  (* ---- transaction processing ---- *)
  val txid     : tx -> txid
  (* Structural validation: empty outputs, non-positive output values, and
     duplicate inputs all raise InvalidTx. (Coinbase = no inputs is allowed.) *)
  val validate : tx -> unit
  (* The miner fee = sum(inputs spent) - sum(outputs). Raises if an input is
     missing. Coinbase transactions have no fee (returns 0). *)
  val fee      : utxo -> tx -> IntInf.int

  (* Apply a single transaction (validates first). Raises DoubleSpend /
     Overspend / InvalidTx on failure. *)
  val apply    : utxo -> tx -> utxo
  (* Non-raising variant: NONE on any failure. *)
  val tryApply : utxo -> tx -> utxo option
  (* Apply a list of transactions in order (a block); fails atomically — if any
     tx fails the whole block is rejected and the original set is returned via
     the exception path (use tryApplyBlock for the option form). *)
  val applyBlock    : utxo -> tx list -> utxo
  val tryApplyBlock : utxo -> tx list -> utxo option
end
