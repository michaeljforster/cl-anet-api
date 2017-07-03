;;;; core.lisp

;;; The MIT License (MIT)
;;;
;;; Copyright (c) 2017 Michael J. Forster
;;;
;;; Permission is hereby granted, free of charge, to any person obtaining a copy
;;; of this software and associated documentation files (the "Software"), to deal
;;; in the Software without restriction, including without limitation the rights
;;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;;; copies of the Software, and to permit persons to whom the Software is
;;; furnished to do so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be included in all
;;; copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;;; SOFTWARE.

(defpackage "CL-ANET-API/CORE"
  (:use "CL")
  (:import-from "ALEXANDRIA")
  (:import-from "WU-DECIMAL")
  (:import-from "CL-JSON")
  (:import-from "PURI")
  (:import-from "DRAKMA")
  (:export "MAKE-MERCHANT-AUTHENTICATION"
           "MAKE-CREDIT-CARD"
           "MAKE-CUSTOMER-ADDRESS"
           ;;
           "TRANSACTION-REQUEST"
           "TRANSACTION-REQUEST-TYPE"
           "TRANSACTION-REQUEST-ALLOW-PARTIAL-AUTH-P"
           "TRANSACTION-REQUEST-DUPLICATE-WINDOW"
           "AUTH-CAPTURE-TRANSACTION-REQUEST"
           ;;
           "TRANSACTION-RESPONSE"
           "AUTH-CAPTURE-TRANSACTION-RESPONSE"
           "TRANSACTION-RESPONSE-RESPONSE-CODE"
           "TRANSACTION-RESPONSE-RESPONSE-CODE-DESCRIPTION"
           "TRANSACTION-RESPONSE-AUTH-CODE"
           "TRANSACTION-RESPONSE-AVS-RESULT-CODE"
           "TRANSACTION-RESPONSE-CVV-RESULT-CODE"
           "TRANSACTION-RESPONSE-CAVV-RESULT-CODE"
           "TRANSACTION-RESPONSE-TRANS-ID"
           "TRANSACTION-RESPONSE-REF-TRANS-ID"
           "TRANSACTION-RESPONSE-TRANS-HASH"
           "TRANSACTION-RESPONSE-ACCOUNT-NUMBER"
           "TRANSACTION-RESPONSE-ACCOUNT-TYPE"
           "TRANSACTION-RESPONSE-MESSAGE-CODE"
           "TRANSACTION-RESPONSE-MESSAGE-DESCRIPTION"
           "TRANSACTION-RESPONSE-ERROR-CODE"
           "TRANSACTION-RESPONSE-ERROR-TEXT"
           ;;
           "REQUEST"
           "REQUEST-MERCHANT-AUTHENTICATION"
           "REQUEST-REF-ID"
           "REQUEST-TRANSACTION-REQUEST"
           ;;
           "RESPONSE"
           "RESPONSE-REF-ID"
           "RESPONSE-RESULT-CODE"
           "RESPONSE-MESSAGE-CODE"
           "RESPONSE-MESSAGE-TEXT"
           "RESPONSE-TRANSACTION-RESPONSE"
           ;;
           "API-ERROR"
           "EXECUTION-FAILED"
           "EXECUTION-FAILED-REQUEST"
           "EXECUTION-FAILED-ENDPOINT"
           "EXECUTION-FAILED-STATUS-CODE"
           "EXECUTION-FAILED-HEADERS"
           "TRANSACTION-FAILED"
           "TRANSACTION-FAILED-REQUEST"
           "TRANSACTION-FAILED-RAW-RESPONSE"
           "EXECUTE"))

(in-package "CL-ANET-API/CORE")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (wu-decimal:enable-reader-macro)
  (wu-decimal:enable-decimal-printing-for-ratios))

(defconstant +http-ok+ 200)

(defparameter *result-code-ok* "Ok")

(defstruct (merchant-authentication (:constructor make-merchant-authentication (api-login-id
                                                                                transaction-key)))
  (api-login-id nil :type string :read-only t)
  (transaction-key nil :type string :read-only t))

(defstruct (credit-card (:constructor make-credit-card (number expiration-date security-code)))
  (number nil :type string :read-only t)
  (expiration-date nil :type string :read-only t)
  (security-code nil :type string :read-only t))

(defstruct customer-address
  (first-name "" :type string :read-only t) ; max. 50 alphanumeric chars
  (last-name "" :type string :read-only t) ; max. 50 alphanumeric chars
  (company "" :type string :read-only t) ; max. 50 alphanumeric chars
  (address "" :type string :read-only t) ; max. 60 alphanumeric chars
  (city "" :type string :read-only t) ; max. 40 alphanumeric chars
  (state "" :type string :read-only t) ; max. 40 alphanumeric chars
  (zip "" :type string :read-only t) ; max. 20 alphanumeric chars
  (country "" :type string :read-only t) ; max. 60 alphanumeric chars
  (phone-number "" :type string :read-only t) ; max. 25 numeric, space, (, ), - chars
  (fax-number "" :type string :read-only t)) ; max. 25 numeric, space, (, ), - chars

(defclass transaction-request () ())

(defgeneric transaction-request-type (transaction-request))

(defgeneric transaction-request-allow-partial-auth-p (transaction-request))

(defgeneric (setf transaction-request-allow-partial-auth-p) (value transaction-request))

(defgeneric transaction-request-duplicate-window (transaction-request))

(defgeneric (setf transaction-request-duplicate-window) (value transaction-request))

;; LATER transaction-request-email-customer-p
;; LATER transaction-request-recurring-billing-p

(defclass auth-capture-transaction-request (transaction-request)
  ((amount :initarg :amount :reader transaction-request-amount) ; total, including tax, shipping, and other charges; 15 digits
   (payment :initarg :payment :reader transaction-request-payment)
   (bill-to :initarg :bill-to :reader transaction-request-bill-to)
   (settings :initform '() :reader transaction-request-settings))
  (:default-initargs
   :amount #$0.00
    :payment nil
    :bill-to nil))

(defmethod transaction-request-type ((transaction-request auth-capture-transaction-request))
  "authCaptureTransaction")

(defmethod transaction-request-allow-partial-auth-p ((transaction-request auth-capture-transaction-request))
  (getf (slot-value transaction-request 'settings) :allow-partial-auth))

(defmethod (setf transaction-request-allow-partial-auth-p) (value (transaction-request auth-capture-transaction-request))
  (check-type value boolean)
  (setf (getf (slot-value transaction-request 'settings) :allow-partial-auth) value))

(defmethod transaction-request-duplicate-window ((transaction-request auth-capture-transaction-request))
  (getf (slot-value transaction-request 'settings) :duplicate-window))

(defmethod (setf transaction-request-duplicate-window) (value (transaction-request auth-capture-transaction-request))
  (check-type value integer)
  (setf (getf (slot-value transaction-request 'settings) :duplicate-window) value))

;; TODO review "refundTransctions" as "Credit" vs. as "Refund a Transaction"
;; TODO (defclass refund-transaction-request (transaction-request)
;;   ((ref-trans-id :initarg :ref-trans-id :reader transaction-request-ref-trans-id))
;;   (:default-initargs
;;    :ref-trans-id ""))

;; TODO (defmethod transaction-request-type ((transaction-request refund-transaction-request))
;;   "refundTransaction")

;; TODO (defclass void-transaction-request (transaction-request)
;;   ((ref-trans-id :initarg :ref-trans-id :reader transaction-request-ref-trans-id))
;;   (:default-initargs
;;    :ref-trans-id ""))

;; TODO (defmethod transaction-request-type ((transaction-request void-transaction-request))
;;   "voidTransaction")

;; LATER auth-only-transaction-request
;; LATER prior-auth-capture-transaction-request (ref-trans-id)
;; LATER capture-only-transaction-request (auth-code)

(defclass transaction-response () ())

(defgeneric transaction-response-response-code (transaction-response))

(defconstant +transaction-response-code-approved+ 1)
(defconstant +transaction-response-code-declined+ 2)
(defconstant +transaction-response-code-error+ 3)
(defconstant +transaction-response-code-held-for-review+ 4)

(defun transaction-response-response-code-description (transaction-response)
  (ecase (transaction-response-response-code transaction-response)
    (+transaction-response-code-approved+ :approved)
    (+transaction-response-code-declined+ :declined)
    (+transaction-response-code-error+ :error)
    (+transaction-response-code-held-for-review+ :held-for-review)))

(defclass auth-capture-transaction-response (transaction-response)
  ((response-code :initarg :response-code :reader transaction-response-response-code)
   (auth-code :initarg :auth-code :reader transaction-response-auth-code)
   (avs-result-code :initarg :avs-result-code :reader transaction-response-avs-result-code)
   (cvv-result-code :initarg :cvv-result-code :reader transaction-response-cvv-result-code)
   (cavv-result-code :initarg :cavv-result-code :reader transaction-response-cavv-result-code)
   (trans-id :initarg :trans-id :reader transaction-response-trans-id)
   ;; NOTE watch JSON decode of "refTransID" as :REF-TRANS-+ID+
   (ref-trans-id :initarg :ref-trans-id :reader transaction-response-ref-trans-id)
   (trans-hash :initarg :trans-hash :reader transaction-response-trans-hash)
   (account-number :initarg :account-number :reader transaction-response-account-number)
   (account-type :initarg :account-type :reader transaction-response-account-type)
   (message-code :initarg :message-code :reader transaction-response-message-code)
   (message-description :initarg :message-description :reader transaction-response-message-description)
   (error-code :initarg :error-code :reader transaction-response-error-code)
   (error-text :initarg :error-text :reader transaction-response-error-text)
   ;; LATER other fields...
   )
  (:default-initargs
   :response-code nil
    :auth-code nil
    :avs-result-code nil
    :cvv-result-code nil
    :cavv-result-code nil
    :trans-id nil
    :ref-trans-id nil
    :trans-hash nil
    :account-number nil
    :account-type nil
    :message-code nil
    :message-description nil
    :error-code nil
    :error-text nil))

;; TODO refun-transaction-response
;; TODO void-transaction-response
;; LATER auth-only-transaction-response
;; LATER prior-auth-capture-transaction-response
;; LATER capture-only-transaction-response

(defclass request ()
  ((merchant-authentication :initarg :merchant-authentication :reader request-merchant-authentication)
   (ref-id :initarg :ref-id :reader request-ref-id)
   (transaction-request :initarg :transaction-request :reader request-transaction-request))
  (:default-initargs
   :merchant-authentication nil
    :ref-id ""
    :transaction-request nil))

(defclass response ()
  ((ref-id :initarg :ref-id :reader response-ref-id)
   (result-code :initarg :result-code :reader response-result-code)
   (message-code :initarg :message-code :reader response-message-code)
   (message-text :initarg :message-text :reader response-message-text)
   (transaction-response :initarg :transaction-response :reader response-transaction-response))
  (:default-initargs
   :ref-id ""
    :result-code ""
    :message-code ""
    :message-text ""
    :transaction-response nil))

(defmethod cl-json:encode-json ((object merchant-authentication) &optional (stream cl-json:*json-output*))
  (with-accessors ((merchant-authentication-api-login-id merchant-authentication-api-login-id)
                   (merchant-authentication-transaction-key merchant-authentication-transaction-key))
      object
    (cl-json:with-object (stream)
      (cl-json:encode-object-member :name merchant-authentication-api-login-id stream)
      (cl-json:encode-object-member :transaction-key merchant-authentication-transaction-key stream))))

(defmethod cl-json:encode-json ((object credit-card) &optional (stream cl-json:*json-output*))
  (with-accessors ((credit-card-number credit-card-number)
                   (credit-card-expiration-date credit-card-expiration-date)
                   (credit-card-security-code credit-card-security-code))
      object
    (cl-json:with-object (stream)
      (cl-json:as-object-member (:credit-card stream)
        (cl-json:with-object (stream)
          (cl-json:encode-object-member :card-number credit-card-number stream)
          (cl-json:encode-object-member :expiration-date credit-card-expiration-date stream)
          (cl-json:encode-object-member :card-code credit-card-security-code stream))))))

(defmethod cl-json:encode-json ((object customer-address) &optional (stream cl-json:*json-output*))
  (with-accessors ((customer-address-first-name customer-address-first-name)
                   (customer-address-last-name customer-address-last-name)
                   (customer-address-company customer-address-company)
                   (customer-address-address customer-address-address)
                   (customer-address-city customer-address-city)
                   (customer-address-state customer-address-state)
                   (customer-address-zip customer-address-zip)
                   (customer-address-country customer-address-country)
                   (customer-address-phone-number customer-address-phone-number)
                   (customer-address-fax-number customer-address-fax-number))
      object
    (cl-json:with-object (stream)
      (cl-json:encode-object-member :first-name customer-address-first-name stream)
      (cl-json:encode-object-member :last-name customer-address-last-name stream)
      (cl-json:encode-object-member :company customer-address-company stream)
      (cl-json:encode-object-member :address customer-address-address stream)
      (cl-json:encode-object-member :city customer-address-city stream)
      (cl-json:encode-object-member :state customer-address-state stream)
      (cl-json:encode-object-member :zip customer-address-zip stream)
      (cl-json:encode-object-member :country customer-address-country stream)
      (cl-json:encode-object-member :phone-number customer-address-phone-number stream)
      (cl-json:encode-object-member :fax-number customer-address-fax-number stream))))

(defmethod cl-json:encode-json ((transaction-request auth-capture-transaction-request)
                                &optional (stream cl-json:*json-output*))
  (with-accessors ((transaction-request-type transaction-request-type)
                   (transaction-request-amount transaction-request-amount)
                   (transaction-request-payment transaction-request-payment)
                   (transaction-request-bill-to transaction-request-bill-to)
                   (transaction-request-settings transaction-request-settings))
      transaction-request
    (cl-json:with-object (stream)
      (cl-json:encode-object-member :transaction-type transaction-request-type stream)
      (cl-json:encode-object-member :amount (format nil "~/wu-decimal:$/" transaction-request-amount)
                                    stream)
      (unless (null transaction-request-payment)
        (cl-json:encode-object-member :payment transaction-request-payment stream))
      (unless (null transaction-request-bill-to)
        (cl-json:encode-object-member :bill-to transaction-request-bill-to stream))
      (unless (null transaction-request-settings) ; assuming a list implementation
        (cl-json:as-object-member (:transaction-settings stream)
          (cl-json:with-object (stream)
            (alexandria:doplist (key value transaction-request-settings)
              (ecase key
                (:allow-partial-auth
                 (cl-json:as-object-member (:setting stream)
                   (cl-json:encode-object-member :setting-name key stream)
                   (cl-json:encode-object-member :setting-value (if value "True" "False")
                                                 stream)))
                (:duplicate-window
                 (cl-json:as-object-member (:setting stream)
                   (cl-json:encode-object-member :setting-name key stream)
                   (cl-json:encode-object-member :setting-value (princ-to-string value)
                                                 stream)))))))))))

(defmethod cl-json:encode-json ((request request) &optional (stream cl-json:*json-output*))
  (with-accessors ((request-merchant-authentication request-merchant-authentication)
                   (request-ref-id request-ref-id)
                   (request-transaction-request request-transaction-request))
      request
    (cl-json:with-object (stream)
      (cl-json:as-object-member (:create-transaction-request stream)
        (cl-json:with-object (stream)
          (cl-json:encode-object-member :merchant-authentication request-merchant-authentication stream)
          (cl-json:encode-object-member :ref-id request-ref-id stream)
          (cl-json:encode-object-member :transaction-request request-transaction-request stream))))))

(define-condition api-error (error)
  ()
  (:documentation "Superclass for all errors signaled by the CL-ANET-API API."))

(define-condition execution-failed (api-error)
  ((request :initarg :request :reader execution-failed-request)
   (endpoint :initarg :endpoint :reader execution-failed-endpoint)
   (status-code :initarg :status-code :reader execution-failed-status-code)
   (headers :initarg :headers :reader execution-failed-headers))
  (:report (lambda (condition stream)
	     (format stream
                     "Execution failed: request = ~A endpoint = ~A status-code = ~A headers = ~A."
                     (execution-failed-request condition)
                     (execution-failed-endpoint condition)
                     (execution-failed-status-code condition)
                     (execution-failed-headers condition))))
  (:documentation "Signalled by EXCUTE when either the API request fails or the response is invalid."))

(define-condition transaction-failed (api-error)
  ((request :initarg :request :reader transaction-failed-request)
   (raw-response :initarg :raw-response :reader transaction-failed-raw-response))
  (:report (lambda (condition stream)
	     (format stream
                     "Transaction failed: request = ~A raw-response = ~A."
                     (transaction-failed-request condition)
                     (transaction-failed-raw-response condition))))
  (:documentation "Signalled by HTTP-GET when the requested transaction fails."))

(defun application-json-content-type-p (content-type)
  (alexandria:starts-with-subseq "application/json" content-type :test #'string-equal))

;; Trim the leading BOM UTF-8 sequence. See https://en.wikipedia.org/wiki/Byte_order_mark.
(defun trim-bom (octets)
  (subseq octets 3))

(defun parse-raw-response (octets)
  (let ((string (flexi-streams:octets-to-string (trim-bom octets)))
        (cl-json:*json-symbols-package* :keyword))
    (cl-json:decode-json-from-string string)))

(defun raw-response-result-code (raw-response)
  (cdr (assoc :result-code (cdr (assoc :messages raw-response)))))

(defun raw-response-ok-p (raw-response)
  (string= *result-code-ok* (raw-response-result-code raw-response)))

(defun raw-response-ref-id (raw-response)
  (cdr (assoc :ref-id raw-response)))

(defun raw-response-message-code (raw-response)
  (cdr (assoc :code (cadr (assoc :message (cdr (assoc :messages raw-response)))))))

(defun raw-response-message-text (raw-response)
  (cdr (assoc :text (cadr (assoc :message (cdr (assoc :messages raw-response)))))))

(defun raw-response-transaction-response (raw-response)
  (cdr (assoc :transaction-response raw-response)))

(defun raw-response-transaction-response-message (raw-response)
  (cadr (assoc :messages (raw-response-transaction-response raw-response))))

(defun raw-response-transaction-response-message-code (raw-response)
  (cdr (assoc :code (raw-response-transaction-response-message raw-response))))

(defun raw-response-transaction-response-message-text (raw-response)
  (cdr (assoc :text (raw-response-transaction-response-message raw-response))))

(defgeneric transaction-request-transaction-response
    (transaction-request raw-response-transaction-response))

(defmethod transaction-request-transaction-response
    ((transaction-request auth-capture-transaction-request)
     raw-response-transaction-response)
  (flet ((value (key)
           (cdr (assoc key raw-response-transaction-response))))
    (let ((message (cadr (assoc :messages raw-response-transaction-response)))
          (err (cadr (assoc :errors raw-response-transaction-response))))
      (make-instance 'auth-capture-transaction-response
                     :response-code (value :response-code)
                     :auth-code (value :auth-code)
                     :avs-result-code (value :avs-result-code)
                     :cvv-result-code (value :cvv-result-code)
                     :cavv-result-code (value :cavv-result-code)
                     :trans-id (value :trans-id)
                     :ref-trans-id (value :ref-trans-+id+) ; Parsed from "refTransID"!
                     :trans-hash (value :trans-hash)
                     :account-number (value :account-number)
                     :account-type (value :account-type)
                     :message-code (cdr (assoc :code message))
                     :message-description (cdr (assoc :description message))
                     :error-code (cdr (assoc :error-code err))
                     :error-text (cdr (assoc :error-text err))))))

(defun execute (request endpoint)
  (check-type request request)
  (check-type endpoint puri:uri)
  (let ((request-json (cl-json:encode-json-to-string request)))
    (multiple-value-bind (body status-code headers uri stream must-close reason-phrase)
        (drakma:http-request endpoint
                             :method :post
                             :force-ssl t
                             :accept "application/json"
                             :content-type "application/json"
                             :content request-json
                             :external-format-out :utf-8
                             :external-format-in :utf-8)
      (declare (ignore uri stream must-close reason-phrase))
      (unless (and (= +http-ok+ status-code)
                   (application-json-content-type-p (drakma:header-value :content-type headers)))
        (error 'execution-failed
               :request request
               :endpoint endpoint
               :status-code status-code
               :headers headers))
      (let ((raw-response (parse-raw-response body)))
        (unless (raw-response-ok-p raw-response)
          (error 'transaction-failed :request request :raw-response raw-response))
        (when (null (raw-response-transaction-response raw-response))
          (error 'transaction-failed :request request :raw-response raw-response))
        (make-instance 'response
                       :ref-id (raw-response-ref-id raw-response)
                       :result-code (raw-response-result-code raw-response)
                       :message-code (raw-response-message-code raw-response)
                       :message-text (raw-response-message-text raw-response)
                       :transaction-response (transaction-request-transaction-response
                                              (request-transaction-request request)
                                              (raw-response-transaction-response raw-response)))))))
