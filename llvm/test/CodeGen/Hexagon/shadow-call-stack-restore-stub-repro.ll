; RUN: llc -mtriple=hexagon -mattr=+reserved-r19 < %s | FileCheck %s --check-prefix=BUG

;; This is a proof/regression seed for the interaction between Hexagon
;; ShadowCallStack and minsize restore stubs.
;;
;; The function is a normal supported LLVM IR entry point:
;;   * shadowcallstack + reserved r19 enables Hexagon SCS.
;;   * minsize triggers useRestoreFunction() even for one callee-saved pair.
;;   * the two calls keep r17:16 live across a call, selecting the existing
;;     __restore_r16_through_r17_and_deallocframe return helper.
;;
;; BUG mode documents the vulnerable output on 2919ad75: the SCS prologue is
;; emitted, but the returning restore stub is used without first reloading r31
;; from the shadow stack or popping r19.
;;
;; FIXED mode documents the intended secure shape: a returning SCS function
;; must not finish through the non-SCS restore/dealloc/return helper.

; BUG-LABEL: restore_stub_scs:
; BUG:       r19 = add(r19,#4)
; BUG:       memw(r19+#-4) = r31
; BUG:       call bar
; BUG-NOT:   r31 = memw(r19+#-4)
; BUG-NOT:   r19 = add(r19,#-4)
; BUG:       jump __restore_r16_through_r17_and_deallocframe
; BUG-NOT:   r31 = memw(r19+#-4)
; BUG-NOT:   r19 = add(r19,#-4)
; BUG:       .Lfunc_end

; FIXED-LABEL: restore_stub_scs:
; FIXED:       r19 = add(r19,#4)
; FIXED:       memw(r19+#-4) = r31
; FIXED-NOT:   __restore_r16_through_r17_and_deallocframe
; FIXED-DAG:   r31 = memw(r19+#-4)
; FIXED-DAG:   r19 = add(r19,#-4)
; FIXED:       jumpr r31

target triple = "hexagon"

define i32 @restore_stub_scs(i32 %x) #0 {
entry:
  %call = call i32 @foo(i32 %x) #1
  %call1 = call i32 @bar(i32 %x, i32 %call) #1
  ret i32 %call1
}

declare i32 @foo(i32) #1
declare i32 @bar(i32, i32) #1

attributes #0 = { nounwind minsize shadowcallstack "disable-tail-calls"="true" }
attributes #1 = { nounwind optsize }
