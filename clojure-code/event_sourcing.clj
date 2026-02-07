;;; =============================================================================
;;; Event Sourcing in Clojure
;;; Equivalent to the FOL event sourcing example (Section 5.2)
;;; =============================================================================

(ns event-sourcing)

;; Account is a plain map---no class definition needed
(defn make-account []
  {:balance 0 :events []})

;; Command dispatch via multimethods
(defmulti apply-command (fn [_agg cmd] (:type cmd)))

(defmethod apply-command :deposit [agg cmd]
  (update agg :balance + (:amount cmd)))

(defmethod apply-command :withdraw [agg cmd]
  (update agg :balance - (:amount cmd)))

;; Event logging must be done at every call site---no :around method.
;; Option A: wrap every call manually
(defn apply-command-logged [agg cmd]
  (let [result (apply-command agg cmd)
        event  {:command cmd :timestamp (System/currentTimeMillis)}]
    (update result :events conj event)))

;; Replay
(defn replay-to [aggregate events]
  (reduce apply-command-logged aggregate events))

;; -------------------------------------------------------------------
;; Alternative: use a middleware-style wrapper (more idiomatic but
;; requires callers to use the wrapper, not the multimethod directly).
;; -------------------------------------------------------------------

(defn wrap-logging [handler]
  (fn [agg cmd]
    (let [result (handler agg cmd)
          event  {:command cmd :timestamp (System/currentTimeMillis)}]
      (update result :events conj event))))

(def apply-command-with-log (wrap-logging apply-command))

(defn replay-to-alt [aggregate events]
  (reduce apply-command-with-log aggregate events))
