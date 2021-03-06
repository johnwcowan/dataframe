(library (dataframe sort)
  (export dataframe-sort
          sort-expr)

  (import (rnrs)
          (only (dataframe df)
                check-dataframe
                dataframe-alist
                make-dataframe)   
          (only (dataframe helpers)
                enumerate
                add-names-ls-vals
                alist-values-map
                remove-duplicates))

  ;; sort ------------------------------------------------------------------------

  ;; as a reminder for myself...
  ;; < as a sort predicate is interpreted as increasing
  ;; i.e., thing on left is smaller than thing on right

  ;; like filter/partition, sort works on columns
  ;; might be less efficient on dataframes with many columns
  ;; than a row-based approach

  (define (dataframe-sort df sort-expr)
    (check-dataframe df "(dataframe-sort df sort-expr)")
    (let* ([predicates (car sort-expr)]
           [names (cadr sort-expr)]
           [alist (dataframe-alist df)]
           [all-names (map car alist)]
           [ranks (sum-row-ranks alist predicates names)]
           [ls-vals-sorted (sort-ls-vals ranks (map cdr alist))])
      (make-dataframe (add-names-ls-vals all-names ls-vals-sorted))))

  (define-syntax sort-expr
    (syntax-rules ()
      [(_ (predicate name) ...)
       (list
        (list predicate ...)
        (list (quote name) ...))]))

  ;; sort list of values in increasing order by ranks
  (define (sort-vals ranks vals)
    (let ([ranks-vals (map cons ranks vals)])
      (map cdr (list-sort (lambda (x y) (< (car x) (car y))) ranks-vals))))
  
  (define (sort-ls-vals ranks ls-vals)
    (map (lambda (vals) (sort-vals ranks vals)) ls-vals))
  
  ;; returns the weighted sum of the ranks for each row
  (define (sum-row-ranks alist predicates names)
    (let* ([ls-vals (alist-values-map alist names)]
           [weights (calc-weights ls-vals)]
           [ls-ranks (map (lambda (predicate ls weight)
                            (rank-list predicate ls weight))
                          predicates ls-vals weights)])
      (apply map + ls-ranks)))

  ;; calculate weights for each column
  ;; logic is to start with arbitrary weight for first column
  ;; and the weights for subsequent columns are the weight from
  ;; the previous column divided by the length of unique values in the current column
  ;; my initial solution didn't anticipate the problem of very large numbers of unique values
  (define (calc-weights ls-vals)
    (define (loop lengths results)
      (if (null? lengths)
          (reverse results)
          (loop (cdr lengths)
                (cons (/ (car results) (car lengths))
                      results))))
    (let* ([unique-vals (map remove-duplicates ls-vals)]
           [unique-lengths (map length unique-vals)])
      (loop (cdr unique-lengths) '(1000))))

  ;; returns list of weighted rank values for every value in ls 
  (define (rank-list predicate ls weight)
    (let* ([unique-sorted (list-sort predicate (remove-duplicates ls))]
           [ranks (map (lambda (x) (* x weight)) (enumerate unique-sorted))]
           [lookup (map cons unique-sorted ranks)]) 
      (map (lambda (x) (cdr (assoc x lookup))) ls)))

  ;; (define (other-names selected-names all-names)
  ;;   (let* ([bools (map (lambda (x) (not (member x selected-names))) all-names)]
  ;;          [ls-rows (transpose (list bools all-names))])
  ;;     (map cadr (filter (lambda (x) (equal? #t (car x))) ls-rows))))

  )

