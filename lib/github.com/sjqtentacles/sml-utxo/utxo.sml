structure Utxo :> UTXO =
struct
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

  type utxo = (outpoint * txout) list

  fun cmpOutpoint (a : outpoint, b : outpoint) =
    let val c = String.compare (#txid a, #txid b)
    in if c <> EQUAL then c else Int.compare (#index a, #index b) end

  fun empty () : utxo = []

  fun lookup (set : utxo) (pt : outpoint) : txout option =
    case List.find (fn (k, _) => cmpOutpoint (k, pt) = EQUAL) set of
      NONE => NONE
    | SOME (_, v) => SOME v

  fun member set pt = Option.isSome (lookup set pt)

  fun size (set : utxo) : int = List.length set

  fun toList (set : utxo) = set
  fun outpointsOf (set : utxo) = List.map #1 set

  fun totalValue (set : utxo) : IntInf.int =
    List.foldl (fn ((_, v), acc) => IntInf.+ (acc, #value v)) (IntInf.fromInt 0) set

  fun balance (set : utxo) pred : IntInf.int =
    List.foldl (fn ((_, v), acc) =>
                   if pred (#scriptPubKey v) then IntInf.+ (acc, #value v) else acc)
               (IntInf.fromInt 0) set

  fun insertSorted (k : outpoint) (v : txout) [] = [(k, v)]
    | insertSorted k v ((k2, v2) :: rest) =
        case cmpOutpoint (k, k2) of
          LESS    => (k, v) :: (k2, v2) :: rest
        | EQUAL   => (k, v) :: rest
        | GREATER => (k2, v2) :: insertSorted k v rest

  fun removeKey (k : outpoint) [] = raise DoubleSpend
    | removeKey k ((k2, v2) :: rest) =
        if cmpOutpoint (k, k2) = EQUAL then rest
        else (k2, v2) :: removeKey k rest

  fun simpleHash (s : string) : string =
    let
      val n = String.size s
      fun go i acc =
        if i >= n then acc
        else go (i + 1) (Word32.+ (Word32.* (acc, 0w31),
                                   Word32.fromInt (Char.ord (String.sub (s, i)))))
    in
      Word32.toString (go 0 0w5381)
    end

  fun serializeOutpoint (pt : outpoint) =
    #txid pt ^ ":" ^ Int.toString (#index pt)

  (* Fold the scriptPubKey of each output into the txid so that two transactions
     spending the same inputs to the same amounts but different recipients get
     distinct ids. *)
  fun txid (tx : tx) : txid =
    let
      val inStr  = String.concat (List.map (fn i => serializeOutpoint (#prevout i)) (#inputs tx))
      val outStr = String.concat
        (List.map (fn outp => IntInf.toString (#value outp) ^ "|" ^ #scriptPubKey outp ^ ";")
                  (#outputs tx))
    in
      simpleHash (inStr ^ "#" ^ outStr)
    end

  fun sumValues (outs : txout list) : IntInf.int =
    List.foldl (fn (outp, acc) => IntInf.+ (acc, #value outp)) (IntInf.fromInt 0) outs

  (* ---- validation ---- *)

  fun validate (tx : tx) : unit =
    let
      val () = if List.null (#outputs tx) then raise InvalidTx "no outputs" else ()
      val () = List.app (fn outp =>
                 if IntInf.<= (#value outp, IntInf.fromInt 0)
                 then raise InvalidTx "non-positive output value" else ()) (#outputs tx)
      (* duplicate inputs (same outpoint twice) *)
      fun hasDup [] = false
        | hasDup (x :: xs) =
            List.exists (fn y => cmpOutpoint (#prevout x, #prevout y) = EQUAL) xs
            orelse hasDup xs
      val () = if hasDup (#inputs tx) then raise InvalidTx "duplicate input" else ()
    in () end

  fun addOutputs newTxid outs set =
    let
      fun addOut (outp, (i, acc)) =
        (i + 1, insertSorted { txid = newTxid, index = i } outp acc)
      val (_, set') = List.foldl addOut (0, set) outs
    in set' end

  fun apply (set : utxo) (tx : tx) : utxo =
    let
      val () = validate tx
      val isCoinbase = List.null (#inputs tx)
      val newTxid = txid tx
    in
      if isCoinbase then addOutputs newTxid (#outputs tx) set
      else
        let
          fun spendInput (inp, (acc, inVal)) =
            let
              val pt = #prevout inp
              val txoutVal = case lookup acc pt of
                NONE        => raise DoubleSpend
              | SOME txoutp => #value txoutp
              val acc' = removeKey pt acc
            in
              (acc', IntInf.+ (inVal, txoutVal))
            end
          val (set', inputTotal) =
            List.foldl spendInput (set, IntInf.fromInt 0) (#inputs tx)
          val outputTotal = sumValues (#outputs tx)
          val () = if IntInf.< (inputTotal, outputTotal) then raise Overspend else ()
        in
          addOutputs newTxid (#outputs tx) set'
        end
    end

  fun tryApply set tx = SOME (apply set tx) handle _ => NONE

  fun fee (set : utxo) (tx : tx) : IntInf.int =
    if List.null (#inputs tx) then IntInf.fromInt 0
    else
      let
        val inTotal =
          List.foldl (fn (inp, acc) =>
              case lookup set (#prevout inp) of
                  NONE => raise DoubleSpend
                | SOME txoutp => IntInf.+ (acc, #value txoutp))
            (IntInf.fromInt 0) (#inputs tx)
        val outTotal = sumValues (#outputs tx)
      in IntInf.- (inTotal, outTotal) end

  fun applyBlock set txs = List.foldl (fn (tx, acc) => apply acc tx) set txs

  fun tryApplyBlock set txs = SOME (applyBlock set txs) handle _ => NONE
end
