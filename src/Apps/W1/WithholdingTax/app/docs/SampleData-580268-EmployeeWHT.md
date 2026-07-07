# Sample Data — Withholding Tax for Employee Transactions

**Work Item:** [#580268](https://dynamicssmb2.visualstudio.com/1fcb79e7-ab07-432a-a3c6-6cf5a88ba4a5/_workitems/edit/580268)
**Purpose:** Demonstrate setup, master, and transactional data for PM review

---

## 1. Setup Data

### 1.1 Withholding Tax Business Posting Groups (Existing Table - 6784)

Added New Fields
"Party Applicability" - Enum "WHT Party Type" - Vendor, Customer, Employee
"Jurisdiction Code" - Code[20]
"Default Certificate Type" - Code[20]

| Code | Description | Party Applicability | Jurisdiction Code | Default Certificate Type |
|---|---|---|---|---|
| `EMP-DOM` | Employee Domestic | Employee | `DOMESTIC` | `CERT-A` |
| `EMP-INTL` | Employee International | Employee | `INTL` | |
| `VEND-DOM` | Vendor Domestic *(existing)* | Vendor | `DOMESTIC` | |

### 1.2 Withholding Tax Product Posting Groups (Existing Table - 6785)

| Code | Description |
|---|---|
| `FEDERAL` | Federal Income Tax |
| `STATE` | State Income Tax |
| `SOCIAL` | Social Insurance Contribution |
| `FLAT15` | Flat 15% Withholding *(single-tax scenarios)* |
| `TRAVEL` | Travel/Per Diem WHT |
| `BONUS` | Bonus/One-time Compensation WHT |

### 1.3 Withholding Tax Posting Setup (Existing Table - 6786)

Renamed "Withholding Tax Minimum Invoice Amount" to "Withholding Threshold Amount"
Renamed "Withholding Tax Calculation Rule" to "Withholding Threshold Type"

Added new Fields
"Calculation Base" - Enum "WHT Calculation Base" - Gross, Net
"Calculation Method" - Enum "WHT Calculation Method" - Simple, Compound
"Threshold Base" - Enum "WHT Threshold Base" - Record, Document, CategoryPeriod, TotalPeriod
"Threshold Period" - Enum "WHT Threshold Period Type" - '', Month, Quarter, Year, Fiscal Year
"Threshold Category" - Code[20] - Expense Category Lookup

| WHT Bus. Post. Group | WHT Prod. Post. Group | WHT % | Calc Base | Calc Method | Prepaid WHT Acct | Payable WHT Acct | Threshold Type | Threshold Amount | Threshold Base | Threshold Period | Threshold Category |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `EMP-DOM` | `FEDERAL` | 10.00 | Gross | Simple | `2310` | `5410` | Greater than or equal to | 0.00 | Record | | |
| `EMP-DOM` | `STATE` | 5.00 | Gross | Simple | `2320` | `5420` | Greater than or equal to | 0.00 | Record | | |
| `EMP-DOM` | `SOCIAL` | 3.00 | Gross | Simple | `2330` | `5430` | Greater than or equal to | 0.00 | Record | | |
| `EMP-DOM` | `FLAT15` | 15.00 | Gross | Simple | `2310` | `5410` | Greater than or equal to | 0.00 | Record | | |
| `EMP-DOM` | `TRAVEL` | 20.00 | Gross | Simple | `2340` | `5440` | Greater than or equal to | 2,000.00 | Category Period | Month | `TRAVEL` |
| `EMP-DOM` | `BONUS` | 25.00 | Net | Simple | `2350` | `5450` | Greater than or equal to | 5,000.00 | Total Period | Year | |

> **G/L Account legend:**
> - `2310–2350` = WHT Prepaid accounts
> - `5410–5450` = WHT Payable (liability) accounts
> - `6100` = Reimbursement Expense, `6200` = Travel Expense, `6300` = Compensation Expense
> - `1100` = Bank Account

### 1.4 Withholding Tax Posting Setup — Compound Scenario

| WHT Bus. Post. Group | WHT Prod. Post. Group | WHT % | Calc Base | Calc Method | Prepaid WHT Acct | Payable WHT Acct | Threshold Type | Threshold Amount | Threshold Base |
|---|---|---|---|---|---|---|---|---|---|
| `EMP-DOM` | `FEDERAL` | 10.00 | Gross | **Compound** | `2310` | `5410` | Greater than or equal to | 0.00 | Record |
| `EMP-DOM` | `STATE` | 5.00 | Gross | **Compound** | `2320` | `5420` | Greater than or equal to | 0.00 | Record |

### 1.5 Withholding Tax Groups (Multi-Component) (New Table)

PK: "WHT Group Code" 

**Group: `EMP-MULTI-TAX`** — Employee Multi-Tax Group

| WHT Group Code | Description | Party Applicability |
|---|---|---|
| `EMP-MULTI-TAX` | Federal + State + Social | Employee |

**Group Lines:** (New Table)

PK: "WHT Group Code", "Line No."

| WHT Group Code | Line No. | WHT Prod. Post. Group | Component Order | Compound Base Includes | Description |
|---|---|---|---|---|---|
| `EMP-MULTI-TAX` | 10000 | `FEDERAL` | 1 | | Federal Income Tax |
| `EMP-MULTI-TAX` | 20000 | `STATE` | 2 | | State Income Tax |
| `EMP-MULTI-TAX` | 30000 | `SOCIAL` | 3 | | Social Insurance |

**Group: `EMP-COMPOUND`** — Compound Calculation Group

| WHT Group Code | Description | Party Applicability |
|---|---|---|
| `EMP-COMPOUND` | Federal + State (Compound) | Employee |

**Group Lines:**

| WHT Group Code | Line No. | WHT Prod. Post. Group | Component Order | Compound Base Includes | Description |
|---|---|---|---|---|---|
| `EMP-COMPOUND` | 10000 | `FEDERAL` | 1 | | Federal (base component) |
| `EMP-COMPOUND` | 20000 | `STATE` | 2 | `FEDERAL` | State (base includes Federal tax) |

### 1.6 Withholding Tax Revenue Types (Existing Table -6787)

| Code | Description | Sequence |
|---|---|---|
| `REIMB` | Reimbursements | 1 |
| `TRAVEL` | Travel & Per Diem | 2 |
| `COMP` | Compensation & Bonuses | 3 |
| `OTHER` | Other Employee Payments | 4 |

### 1.7 Expense Categories (with WHT Selection) (Existing Table - 6921)

Added New Fields
"WHT Selection Mode" - Enum - "WHT Selection Mode" - Single Tax, Tax Group
"WHT Prod. Post. Group" - Code[20]
"WHT Group Code" - Code[20]

| Code | Description | WHT Selection Mode | WHT Prod. Post. Group | WHT Group Code |
|---|---|---|---|---|
| `REIMBURSE` | Professional Svc Reimbursement | Single Tax | `FLAT15` | |
| `TRAVEL` | Travel & Per Diem | Single Tax | `TRAVEL` | |
| `PROJECT` | One-time Project Compensation | Tax Group | | `EMP-MULTI-TAX` |
| `BONUS` | Bonus Outside Payroll | Single Tax | `BONUS` | |
| `COMPOUND-PAY` | Payment with Compound WHT | Tax Group | | `EMP-COMPOUND` |

---

## 2. Master Data

### 2.1 Employees (Existing Table - 5200)

Added New Fields
"WHT Bus. Post. Group" - Code[20]
"WHT Certificate No." - Code[20]
"WHT Certificate Type" - Code[20]
"Withholding Exempt" - Boolean

| Employee No. | Name | WHT Bus. Post. Group | WHT Certificate No. | WHT Certificate Type | Withholding Exempt |
|---|---|---|---|---|---|
| `EMP001` | Sarah Johnson | `EMP-DOM` | `CERT-2026-001` | `CERT-A` | No |
| `EMP002` | Michael Chen | `EMP-DOM` | `CERT-2026-002` | `CERT-A` | No |
| `EMP003` | Lisa Martinez | `EMP-DOM` | | | **Yes** *(exempt)* |
| `EMP004` | James Wilson | `EMP-INTL` | `CERT-2026-004` | | No |

### 2.2 G/L Accounts (Existing Table - 15)

| G/L Account No. | Name | WHT Bus. Post. Group | WHT Prod. Post. Group |
|---|---|---|---|
| `1100` | Bank—Operating | | |
| `2310` | WHT Prepaid—Federal | | |
| `2320` | WHT Prepaid—State | | |
| `2330` | WHT Prepaid—Social | | |
| `2340` | WHT Prepaid—Travel | | |
| `2350` | WHT Prepaid—Bonus | | |
| `5410` | WHT Payable—Federal | | |
| `5420` | WHT Payable—State | | |
| `5430` | WHT Payable—Social | | |
| `5440` | WHT Payable—Travel | | |
| `5450` | WHT Payable—Bonus | | |
| `6100` | Reimbursement Expense | | `FLAT15` |
| `6200` | Travel Expense | | `TRAVEL` |
| `6300` | Compensation Expense | | `FEDERAL` |

---

## 3. Transactional Data — Scenario Walkthroughs

### Scenario 1: Employee Reimbursement with Single WHT Component

> **Sarah (EMP001) submits a 10,000 professional services reimbursement.**
> Single Tax mode · Prod Group = `FLAT15` · 15% WHT · Gross base

**General Journal Line (input):**

| Field | Value |
|---|---|
| Posting Date | 2026-07-15 |
| Document No. | `EMP-JNL-0001` |
| Account Type | Employee |
| Account No. | `EMP001` |
| Description | Professional svc reimbursement |
| Amount | -10,000.00 |
| Bal. Account Type | Bank Account |
| Bal. Account No. | `1100` |
| WHT Bus. Post. Group | `EMP-DOM` *(from Employee card)* |
| WHT Prod. Post. Group | `FLAT15` *(from expense category)* |

**Result — Employee Ledger Entry:**

| Entry No. | Employee No. | Posting Date | Document No. | Amount | WHT Amount | WHT Base Amount |
|---|---|---|---|---|---|---|
| 1001 | `EMP001` | 2026-07-15 | `EMP-JNL-0001` | -10,000.00 | -1,500.00 | -10,000.00 |

**Result — Withholding Tax Entry:**

| Entry No. | Party Type | Employee No. | ELE Entry No. | Document No. | WHT Bus. Post. Group | WHT Prod. Post. Group | WHT % | Base | Amount | Calc Base | Calc Method | Threshold Exceeded |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 5001 | Employee | `EMP001` | 1001 | `EMP-JNL-0001` | `EMP-DOM` | `FLAT15` | 15.00 | 10,000.00 | 1,500.00 | Gross | Simple | Yes |

**Result — G/L Entries:**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6100` | Reimbursement Expense | 10,000.00 | |
| `1100` | Bank—Operating | | 8,500.00 |
| `5410` | WHT Payable—Federal | | 1,500.00 |

---

### Scenario 2: Multi-Component WHT (Tax Group — Federal + State + Social)

> **Michael (EMP002) receives a one-time project compensation of 20,000.**
> Tax Group `EMP-MULTI-TAX` · 3 components · Simple method · Gross base

**General Journal Line (input):**

| Field | Value |
|---|---|
| Posting Date | 2026-07-20 |
| Document No. | `EMP-JNL-0002` |
| Account Type | Employee |
| Account No. | `EMP002` |
| Amount | -20,000.00 |
| Bal. Account Type | Bank Account |
| Bal. Account No. | `1100` |
| WHT Bus. Post. Group | `EMP-DOM` |
| WHT Group Code | `EMP-MULTI-TAX` |

**Calculation:**

| Component | WHT Prod. Group | Base | WHT % | WHT Amount |
|---|---|---|---|---|
| Federal (Order 1) | `FEDERAL` | 20,000.00 | 10% | 2,000.00 |
| State (Order 2) | `STATE` | 20,000.00 | 5% | 1,000.00 |
| Social (Order 3) | `SOCIAL` | 20,000.00 | 3% | 600.00 |
| **Total WHT** | | | | **3,600.00** |

**Result — Employee Ledger Entry:**

| Entry No. | Employee No. | Document No. | Amount | WHT Amount | WHT Base Amount |
|---|---|---|---|---|---|
| 1002 | `EMP002` | `EMP-JNL-0002` | -20,000.00 | -3,600.00 | -20,000.00 |

**Result — Withholding Tax Entries (3 entries linked to 1 ELE):**

| Entry No. | Party Type | Employee No. | ELE Entry No. | WHT Prod. Post. Group | WHT % | Base | Amount | Component Order | Calc Method |
|---|---|---|---|---|---|---|---|---|---|
| 5002 | Employee | `EMP002` | 1002 | `FEDERAL` | 10.00 | 20,000.00 | 2,000.00 | 1 | Simple |
| 5003 | Employee | `EMP002` | 1002 | `STATE` | 5.00 | 20,000.00 | 1,000.00 | 2 | Simple |
| 5004 | Employee | `EMP002` | 1002 | `SOCIAL` | 3.00 | 20,000.00 | 600.00 | 3 | Simple |

**Result — G/L Entries:**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6300` | Compensation Expense | 20,000.00 | |
| `1100` | Bank—Operating | | 16,400.00 |
| `5410` | WHT Payable—Federal | | 2,000.00 |
| `5420` | WHT Payable—State | | 1,000.00 |
| `5430` | WHT Payable—Social | | 600.00 |

---

### Scenario 3: Net (Gross-up) Withholding

> **Sarah (EMP001) is promised a net bonus of 7,500.**
> Single Tax `BONUS` · 25% WHT · **Net (Gross-up)** base

**General Journal Line (input):**

| Field | Value |
|---|---|
| Posting Date | 2026-08-01 |
| Document No. | `EMP-JNL-0003` |
| Account Type | Employee |
| Account No. | `EMP001` |
| Amount | -7,500.00 *(net amount employee receives)* |
| Bal. Account Type | Bank Account |
| Bal. Account No. | `1100` |
| WHT Bus. Post. Group | `EMP-DOM` |
| WHT Prod. Post. Group | `BONUS` |

**Calculation (Gross-up):**

| Step | Formula | Result |
|---|---|---|
| Gross amount | 7,500 / (1 − 0.25) = 7,500 / 0.75 | **10,000.00** |
| WHT amount | 10,000.00 × 25% | **2,500.00** |
| Net paid to employee | 10,000.00 − 2,500.00 | **7,500.00** |

**Result — Employee Ledger Entry:**

| Entry No. | Employee No. | Document No. | Amount | WHT Amount | WHT Base Amount |
|---|---|---|---|---|---|
| 1003 | `EMP001` | `EMP-JNL-0003` | -7,500.00 | -2,500.00 | -10,000.00 |

**Result — Withholding Tax Entry:**

| Entry No. | Party Type | Employee No. | ELE Entry No. | WHT Prod. Post. Group | WHT % | Base | Amount | Calc Base | Taxable Base Amount |
|---|---|---|---|---|---|---|---|---|---|
| 5005 | Employee | `EMP001` | 1003 | `BONUS` | 25.00 | 10,000.00 | 2,500.00 | Net | 10,000.00 |

**Result — G/L Entries:**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6300` | Compensation Expense | 10,000.00 | |
| `1100` | Bank—Operating | | 7,500.00 |
| `5450` | WHT Payable—Bonus | | 2,500.00 |

---

### Scenario 4: Travel Allowance Exceeding Threshold (Category in Period)

> **Michael (EMP002) posts three travel claims in July 2026.**
> `TRAVEL` · 20% WHT · Threshold = 2,000/month per category `TRAVEL`
> WHT applies only when cumulative travel exceeds 2,000 in the month.

**Transaction sequence:**

| # | Date | Document No. | Description | Amount |
|---|---|---|---|---|
| 1 | 2026-07-05 | `EMP-JNL-0010` | Travel claim — week 1 | 800.00 |
| 2 | 2026-07-15 | `EMP-JNL-0011` | Travel claim — week 2 | 900.00 |
| 3 | 2026-07-25 | `EMP-JNL-0012` | Travel claim — week 3 | 1,500.00 |

**Threshold evaluation (cumulative):**

| Txn | Amount | Running Total | Threshold | WHT Applies? | Taxable Base | WHT (20%) |
|---|---|---|---|---|---|---|
| 1 | 800.00 | 800.00 | 2,000.00 | **No** — below threshold | 0.00 | 0.00 |
| 2 | 900.00 | 1,700.00 | 2,000.00 | **No** — below threshold | 0.00 | 0.00 |
| 3 | 1,500.00 | 3,200.00 | 2,000.00 | **Yes** — 3,200 ≥ 2,000 | 1,500.00 | 300.00 |

**Result — WHT Entry (only Txn #3 creates a WHT entry):**

| Entry No. | Employee No. | Document No. | Posting Date | WHT Prod. Post. Group | Base | Amount | Threshold Base | Threshold Exceeded | Period Start | Period End | Expense Category |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 5010 | `EMP002` | `EMP-JNL-0012` | 2026-07-25 | `TRAVEL` | 1,500.00 | 300.00 | Category Period | Yes | 2026-07-01 | 2026-07-31 | `TRAVEL` |

**Result — WHT Threshold Accumulator (after all 3 transactions):**

| Employee No. | WHT Bus. Group | WHT Prod. Group | Threshold Base | Period Start | Period End | Expense Category | Accum. Base Amt | Accum. WHT Amt |
|---|---|---|---|---|---|---|---|---|
| `EMP002` | `EMP-DOM` | `TRAVEL` | Category Period | 2026-07-01 | 2026-07-31 | `TRAVEL` | 3,200.00 | 300.00 |

**Result — G/L Entries (Txn #3 only — Txns #1 & #2 post with zero WHT):**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6200` | Travel Expense | 1,500.00 | |
| `1100` | Bank—Operating | | 1,200.00 |
| `5440` | WHT Payable—Travel | | 300.00 |

**G/L Entries for Txn #1 (800.00, no WHT):**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6200` | Travel Expense | 800.00 | |
| `1100` | Bank—Operating | | 800.00 |

**G/L Entries for Txn #2 (900.00, no WHT):**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6200` | Travel Expense | 900.00 | |
| `1100` | Bank—Operating | | 900.00 |

---

### Scenario 5: Compound Calculation (Federal + State with Base Inclusion)

> **Sarah (EMP001) receives a 10,000 payment with compound WHT.**
> Group `EMP-COMPOUND` · Federal 10% (order 1) · State 5% (order 2, base includes Federal)

**General Journal Line (input):**

| Field | Value |
|---|---|
| Posting Date | 2026-08-15 |
| Document No. | `EMP-JNL-0020` |
| Account Type | Employee |
| Account No. | `EMP001` |
| Amount | -10,000.00 |
| Bal. Account Type | Bank Account |
| Bal. Account No. | `1100` |
| WHT Bus. Post. Group | `EMP-DOM` |
| WHT Group Code | `EMP-COMPOUND` |

**Calculation:**

| Step | Component | Order | Base Calculation | Base | WHT % | WHT Amount |
|---|---|---|---|---|---|---|
| 1 | Federal | 1 | Original amount | 10,000.00 | 10% | 1,000.00 |
| 2 | State | 2 | Original + Federal WHT = 10,000 + 1,000 | **11,000.00** | 5% | 550.00 |
| | **Total** | | | | | **1,550.00** |

Net paid to employee: 10,000.00 − 1,550.00 = **8,450.00**

**Result — Employee Ledger Entry:**

| Entry No. | Employee No. | Document No. | Amount | WHT Amount | WHT Base Amount |
|---|---|---|---|---|---|
| 1005 | `EMP001` | `EMP-JNL-0020` | -10,000.00 | -1,550.00 | -10,000.00 |

**Result — Withholding Tax Entries:**

| Entry No. | Employee No. | ELE Entry No. | WHT Prod. Post. Group | WHT % | Base | Amount | Component Order | Calc Method |
|---|---|---|---|---|---|---|---|---|
| 5020 | `EMP001` | 1005 | `FEDERAL` | 10.00 | 10,000.00 | 1,000.00 | 1 | Compound |
| 5021 | `EMP001` | 1005 | `STATE` | 5.00 | 11,000.00 | 550.00 | 2 | Compound |

**Result — G/L Entries:**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6100` | Reimbursement Expense | 10,000.00 | |
| `1100` | Bank—Operating | | 8,450.00 |
| `5410` | WHT Payable—Federal | | 1,000.00 |
| `5420` | WHT Payable—State | | 550.00 |

---

### Scenario 6: Reversal / Correction

> **Reverse Scenario 1 (EMP-JNL-0001) originally posted on 2026-07-15.**

**Reversing General Journal:**

| Field | Value |
|---|---|
| Posting Date | 2026-07-18 |
| Document No. | `EMP-JNL-0001-REV` |
| Account Type | Employee |
| Account No. | `EMP001` |
| Amount | +10,000.00 *(reversal)* |

**Result — Reversing WHT Entry:**

| Entry No. | Party Type | Employee No. | Document No. | WHT Prod. Post. Group | Base | Amount | Reversed Entry No. | Reversed |
|---|---|---|---|---|---|---|---|---|
| 5030 | Employee | `EMP001` | `EMP-JNL-0001-REV` | `FLAT15` | -10,000.00 | -1,500.00 | 5001 | No |

**Original WHT Entry #5001 (updated):**

| Entry No. | Reversed by Entry No. | Reversed |
|---|---|---|
| 5001 | 5030 | **Yes** |

**Result — Reversing G/L Entries:**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6100` | Reimbursement Expense | | 10,000.00 |
| `1100` | Bank—Operating | 8,500.00 | |
| `5410` | WHT Payable—Federal | 1,500.00 | |

**Accumulator impact:** Any period accumulator that included Scenario 1 is decremented by Base = 10,000 and WHT = 1,500.

---

### Scenario 7: Exempt Employee — No WHT

> **Lisa (EMP003) submits a 5,000 reimbursement. She is marked Withholding Exempt = Yes.**

**General Journal Line (input):**

| Field | Value |
|---|---|
| Posting Date | 2026-07-20 |
| Document No. | `EMP-JNL-0040` |
| Account Type | Employee |
| Account No. | `EMP003` |
| Amount | -5,000.00 |
| Bal. Account Type | Bank Account |
| Bal. Account No. | `1100` |

**Result:** System checks `Withholding Exempt = Yes` on Employee card → **zero WHT calculated**.

**Result — Employee Ledger Entry:**

| Entry No. | Employee No. | Document No. | Amount | WHT Amount | WHT Base Amount |
|---|---|---|---|---|---|
| 1010 | `EMP003` | `EMP-JNL-0040` | -5,000.00 | 0.00 | 0.00 |

**Result — WHT Entry:** *None created.*

**Result — G/L Entries:**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6100` | Reimbursement Expense | 5,000.00 | |
| `1100` | Bank—Operating | | 5,000.00 |

---

## 4. Data Summary

### Entry Counts by Scenario

| # | Scenario | Employee Ledger Entries | WHT Entries | G/L Entries |
|---|---|---|---|---|
| 1 | Single WHT (Gross) | 1 | 1 | 3 |
| 2 | Multi-Component (Tax Group) | 1 | 3 | 5 |
| 3 | Net (Gross-up) | 1 | 1 | 3 |
| 4 | Threshold (3 txns in month) | 3 | 1 *(only txn 3)* | 9 *(3+3+3)* |
| 5 | Compound WHT | 1 | 2 | 4 |
| 6 | Reversal | 1 *(reversing)* | 1 *(reversing)* | 3 *(reversing)* |
| 7 | Exempt Employee | 1 | 0 | 2 |
| | **Totals** | **9** | **9** | **29** |

---

## 5. Reporting Sample Output

### Employee WHT Summary — July 2026

| Employee No. | Employee Name | Jurisdiction | WHT Component | Total Base | Total WHT | Period |
|---|---|---|---|---|---|---|
| `EMP001` | Sarah Johnson | DOMESTIC | FLAT15 (15%) | 10,000.00 | 1,500.00 | Jul 2026 |
| `EMP002` | Michael Chen | DOMESTIC | FEDERAL (10%) | 20,000.00 | 2,000.00 | Jul 2026 |
| `EMP002` | Michael Chen | DOMESTIC | STATE (5%) | 20,000.00 | 1,000.00 | Jul 2026 |
| `EMP002` | Michael Chen | DOMESTIC | SOCIAL (3%) | 20,000.00 | 600.00 | Jul 2026 |
| `EMP002` | Michael Chen | DOMESTIC | TRAVEL (20%) | 1,500.00 | 300.00 | Jul 2026 |

### Employee WHT Summary — August 2026

| Employee No. | Employee Name | Jurisdiction | WHT Component | Total Base | Total WHT | Period |
|---|---|---|---|---|---|---|
| `EMP001` | Sarah Johnson | DOMESTIC | BONUS (25%) | 10,000.00 | 2,500.00 | Aug 2026 |
| `EMP001` | Sarah Johnson | DOMESTIC | FEDERAL (10%) | 10,000.00 | 1,000.00 | Aug 2026 |
| `EMP001` | Sarah Johnson | DOMESTIC | STATE (5%) | 11,000.00 | 550.00 | Aug 2026 |

### WHT Liability Summary — July 2026

| Payable G/L Account | Account Name | Jurisdiction | Total Liability |
|---|---|---|---|
| `5410` | WHT Payable—Federal | DOMESTIC | 3,500.00 |
| `5420` | WHT Payable—State | DOMESTIC | 1,000.00 |
| `5430` | WHT Payable—Social | DOMESTIC | 600.00 |
| `5440` | WHT Payable—Travel | DOMESTIC | 300.00 |
| | **Grand Total** | | **5,400.00** |

### WHT Liability Summary — August 2026

| Payable G/L Account | Account Name | Jurisdiction | Total Liability |
|---|---|---|---|
| `5410` | WHT Payable—Federal | DOMESTIC | 1,000.00 |
| `5420` | WHT Payable—State | DOMESTIC | 550.00 |
| `5450` | WHT Payable—Bonus | DOMESTIC | 2,500.00 |
| | **Grand Total** | | **4,050.00** |
