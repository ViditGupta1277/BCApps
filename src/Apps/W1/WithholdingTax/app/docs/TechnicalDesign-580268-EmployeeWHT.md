# Technical Design Document — Withholding Tax for Employee Transactions

| Field | Value |
|---|---|
| **Work Item** | [#580268](https://dynamicssmb2.visualstudio.com/1fcb79e7-ab07-432a-a3c6-6cf5a88ba4a5/_workitems/edit/580268) |
| **Title** | [VENDOR] Withholding Tax for Employee transactions |
| **Iteration** | Wave 2 2026 |
| **Area** | Dynamics SMB \ AI Business Solutions \ Finance |
| **Country/Region** | W1 |
| **Risk** | High |
| **Effort** | 5 |
| **PM Owner** | Aleksandar Totovic |
| **App** | Withholding Tax (`c31ee575-3fc7-4388-98ee-d75aa2fc5f87`) |
| **ID Range** | 6784–6813 (30 IDs allocated) |

---

## 1. Background & Motivation

The Withholding Tax app currently supports **Vendor** (purchase) transactions only. The entire object model — tables, codeunits, pages, and reports — is purchase-centric with no Employee or HR references.

Many jurisdictions also require **withholding on employee payments outside payroll**, including:

- Professional services reimbursements
- Travel/per diem above tax-free thresholds
- Mileage above tax-free thresholds
- One-time compensation, bonuses outside payroll
- Stock awards, severance, termination payments

This slice extends WHT to **Employees** while reusing the existing setup infrastructure (posting groups, posting setup) and adding new concepts for multi-component tax, threshold accumulation, and gross-up (net) calculation.

---

## 2. Scope

### In Scope

| Area | Description |
|---|---|
| Employee as WHT party type | Employee card extended with WHT Bus. Post. Group, certificate fields, and exemption flag |
| Multi-tax per employee transaction | New Withholding Tax Group table that maps to N product posting groups |
| Gross-up (net) calculation | New calculation base option on posting setup |
| Compound calculation method | Component ordering with base inclusion/exclusion |
| Threshold accumulation | Period-based accumulators per employee / category / total |
| Journal posting | General Journal (Account Type = Employee) triggers WHT calculation + entry creation |
| Withholding Tax Entry | Extended for Employee party type with new audit fields |
| Reporting datasets | Period summary, liability summary, transaction list |

### Out of Scope

- Full payroll integration
- Country-specific statutory report formats (extensibility only)
- Expense report integration (separate slice)

---

## 3. Existing Object Inventory (Baseline)

Objects being **extended** or **referenced** by this slice:

### 3.1 Core Tables (Existing)

| ID | Object | Key Fields |
|---|---|---|
| 6784 | `Wthldg. Tax Bus. Post. Group` | Code, Description |
| 6785 | `Wthldg. Tax Prod. Post. Group` | Code, Description |
| 6786 | `Withholding Tax Posting Setup` | Bus Group (PK), Prod Group (PK), WHT %, Prepaid/Payable Acc Codes, Revenue Type, Realized WHT Type, Min Inv Amount, Calculation Rule |
| 6787 | `Withholding Tax Revenue Types` | Code, Description, Sequence |
| 6788 | `Withholding Tax Entry` | Entry No (PK), Doc No, Posting Date, Base, Amount, Unrealized/Realized tracking, Transaction Type (Purchase/Sale/Settlement), Bill-to/Pay-to No |

### 3.2 Key Codeunits (Existing)

| ID | Object | Responsibility |
|---|---|---|
| 6784 | `Wthldg Tax Purch. Subscribers` | Event subscribers copying WHT groups to purchase documents/buffers |
| 6785 | `Withholding Tax Mgmt.` | Core calculation & posting logic — `InsertVendInvoiceWithholdingTax`, `InsertVendJournalWithholdingTax`, `InsertWithholdingTax`, `CheckWithholdingCalculationRule`, `ProcessPayment`, rounding |
| 6786 | `Withholding Tax Jnl Subscriber` | Journal event handlers — field clearing, validation, PDC |
| 6787 | `Wthldg Tax Navigate Handler` | Navigate page integration |
| 6788 | `G/L Reg.-Withholding Entries` | G/L Register ↔ WHT Entry linking |
| 6789 | `Withholding Tax Event Handler` | Where-Used registration |
| 6792 | `Wthldg Tax Preview Handler` | Posting preview |

### 3.3 ID Range Availability

Current range: **6784–6813** (30 IDs). Many IDs are consumed. New objects will need additional IDs from this range or a new allocation.

**Used IDs:** 6784–6802, 6804–6808 (tables/tableexts); 6784–6798 (pages/pageexts); 6784–6789, 6792 (codeunits).

**Available IDs for new objects:** Estimate ~5–8 remaining slots in 6784–6813. A new ID range allocation is likely required for the employee extension.

---

## 4. New & Modified Objects

### 4.1 New Enums

#### Enum: `WHT Party Type`
```
enum XXXX "WHT Party Type"
{
    Extensible = true;
    value(0; Vendor) { Caption = 'Vendor'; }
    value(1; Customer) { Caption = 'Customer'; }
    value(2; Employee) { Caption = 'Employee'; }
}
```

#### Enum: `WHT Calculation Base`
```
enum XXXX "WHT Calculation Base"
{
    value(0; Gross) { Caption = 'Gross'; }
    value(1; Net) { Caption = 'Net (Gross-up)'; }
}
```

#### Enum: `WHT Calculation Method`
```
enum XXXX "WHT Calculation Method"
{
    value(0; Simple) { Caption = 'Simple'; }
    value(1; Compound) { Caption = 'Compound'; }
}
```

#### Enum: `WHT Threshold Base`
```
enum XXXX "WHT Threshold Base"
{
    value(0; Record) { Caption = 'Record/Line'; }
    value(1; Document) { Caption = 'Document'; }
    value(2; "Category Period") { Caption = 'Category in Period'; }
    value(3; "Total Period") { Caption = 'Total in Period'; }
}
```

#### Enum: `WHT Threshold Period`
```
enum XXXX "WHT Threshold Period"
{
    value(0; Month) { Caption = 'Month'; }
    value(1; Quarter) { Caption = 'Quarter'; }
    value(2; Year) { Caption = 'Year'; }
    value(3; "Fiscal Period") { Caption = 'Fiscal Period'; }
}
```

#### Enum: `WHT Selection Mode`
```
enum XXXX "WHT Selection Mode"
{
    value(0; "Single Tax") { Caption = 'Single Tax'; }
    value(1; "Tax Group") { Caption = 'Tax Group'; }
}
```

---

### 4.2 New Tables

#### Table: `Withholding Tax Group` (new)

Enables multi-component withholding for a single employee transaction.

| Field | Type | Description |
|---|---|---|
| Code | Code[20] | PK |
| Description | Text[100] | |
| Party Applicability | Enum "WHT Party Type" | Initially Employee only |

#### Table: `Withholding Tax Group Line` (new)

Lines of a WHT Group — each line maps to a product posting group.

| Field | Type | Description |
|---|---|---|
| WHT Group Code | Code[20] | PK, TableRelation → Withholding Tax Group |
| Line No. | Integer | PK |
| Wthldg. Tax Prod. Post. Group | Code[20] | TableRelation → Wthldg. Tax Prod. Post. Group |
| Component Order | Integer | Execution order for compound calculation |
| Compound Base Includes | Text[250] | Comma-separated Prod Group codes whose tax is included in this component's base |
| Description | Text[100] | |

#### Table: `WHT Threshold Accumulator` (new)

Tracks accumulated WHT base amounts per employee, period, and optionally category for threshold evaluation.

| Field | Type | Description |
|---|---|---|
| Entry No. | Integer | PK, AutoIncrement |
| Employee No. | Code[20] | TableRelation → Employee |
| Wthldg. Tax Bus. Post. Group | Code[20] | |
| Wthldg. Tax Prod. Post. Group | Code[20] | |
| Threshold Base | Enum "WHT Threshold Base" | Record/Document/Category Period/Total Period |
| Period Start Date | Date | Start of accumulation period |
| Period End Date | Date | End of accumulation period |
| Expense Category Code | Code[20] | Blank for Total Period |
| Accumulated Base Amount | Decimal | Running total of WHT base |
| Accumulated WHT Amount | Decimal | Running total of WHT withheld |

**Keys:**
- PK: Entry No.
- Key2: Employee No., Threshold Base, Expense Category Code, Period Start Date, Period End Date (SumIndexFields: Accumulated Base Amount, Accumulated WHT Amount)

---

### 4.3 Modified Tables (Field Additions)

#### Table 6784 `Wthldg. Tax Bus. Post. Group` — add fields

| Field ID | Name | Type | Description |
|---|---|---|---|
| TBD | Party Applicability | Enum "WHT Party Type" | Which party types this group applies to |
| TBD | Jurisdiction Code | Code[20] | Optional jurisdiction classification |
| TBD | Default Certificate Type | Code[20] | Default certificate type for this group |

#### Table 6786 `Withholding Tax Posting Setup` — add fields

| Field ID | Name | Type | Description |
|---|---|---|---|
| TBD | Calculation Base | Enum "WHT Calculation Base" | Gross / Net (gross-up). Employee only. |
| TBD | Calculation Method | Enum "WHT Calculation Method" | Simple / Compound. Employee only. |
| TBD | WHT Threshold Base | Enum "WHT Threshold Base" | Record / Document / Category Period / Total Period |
| TBD | WHT Threshold Period | Enum "WHT Threshold Period" | Month / Quarter / Year / Fiscal. Relevant when Threshold Base = Category Period or Total Period. |
| TBD | Threshold Category Code | Code[20] | Expense category for Category Period threshold |

> **Caption renames** (not field renames — use new CaptionML or caption property):
> - Existing field 25 `Wthldg. Tax Calculation Rule` → caption: **"WHT Threshold Type"**
> - Existing field 24 `Wthldg. Tax Min. Inv. Amount` → caption: **"WHT Threshold Amount"**

#### Table 6788 `Withholding Tax Entry` — add fields

| Field ID | Name | Type | Description |
|---|---|---|---|
| TBD | Party Type | Enum "WHT Party Type" | Vendor / Customer / Employee |
| TBD | Employee No. | Code[20] | TableRelation → Employee. Populated when Party Type = Employee. |
| TBD | Employee Ledger Entry No. | Integer | Link to ELE |
| TBD | Calculation Base | Enum "WHT Calculation Base" | Gross / Net used for this entry |
| TBD | Calculation Method | Enum "WHT Calculation Method" | Simple / Compound |
| TBD | Component Order | Integer | Order in compound chain |
| TBD | Threshold Base | Enum "WHT Threshold Base" | Which threshold was applied |
| TBD | Threshold Evaluated | Boolean | Whether threshold was evaluated |
| TBD | Threshold Exceeded | Boolean | Whether threshold was exceeded |
| TBD | Period Start Date | Date | Accumulation period start |
| TBD | Period End Date | Date | Accumulation period end |
| TBD | Expense Category Code | Code[20] | For category-based accumulation |
| TBD | WHT Group Code | Code[20] | Withholding Tax Group used (if multi-tax) |
| TBD | Taxable Base Amount | Decimal | Base amount after threshold evaluation |

> Existing field `Bill-to/Pay-to No.` (12) TableRelation must be extended to include Employee when Party Type = Employee.

> Existing field `Transaction Type` (27) option string must be extended to include `Employee` (or use new Party Type enum for routing).

#### New Table Extension: `Employee` table — add fields

| Field ID | Name | Type | Location on Page |
|---|---|---|---|
| TBD | WHT Bus. Post. Group | Code[20] | Payments FastTab |
| TBD | WHT Certificate No. | Code[20] | Payments FastTab (ShowMore) |
| TBD | WHT Certificate Type | Code[20] | Payments FastTab (ShowMore) |
| TBD | Withholding Exempt | Boolean | Payments FastTab (ShowMore) |

#### New Table Extension: `Employee Ledger Entry` table — add fields

| Field ID | Name | Type | Description |
|---|---|---|---|
| TBD | WHT Amount | Decimal | Total WHT withheld for this ELE |
| TBD | WHT Base Amount | Decimal | Total WHT base for this ELE |

---

### 4.4 New / Modified Pages

| Action | Object | Changes |
|---|---|---|
| **New** | Withholding Tax Group List (Page) | List page for WHT Group table |
| **New** | Withholding Tax Group Card (Page) | Card page with subform for Group Lines |
| **New** | WHT Threshold Accumulators (Page) | Read-only list of accumulator entries for auditing |
| **Modify** | Employee Card (PageExt) | Add WHT Bus. Post. Group, Certificate No., Certificate Type, Withholding Exempt to Payments FastTab |
| **Modify** | Withholding Tax Posting Setup (Page 6786) | Add Calculation Base, Calculation Method, Threshold Base, Threshold Period, Threshold Category fields |
| **Modify** | Wthldg. Tax Bus. Post. Group (Page 6784) | Add Party Applicability, Jurisdiction Code columns |
| **Modify** | Withholding Tax Entries (Page 6788) | Add Party Type, Employee No., ELE Entry No., Calculation Base/Method, Component Order, Threshold fields |
| **Modify** | General Journal (PageExt or existing ext 6786) | Show withholding breakdown action for Employee lines |

---

### 4.5 Codeunit Changes

#### Codeunit 6785 `Withholding Tax Mgmt.` — Major Modifications

New procedures:

| Procedure | Description |
|---|---|
| `InsertEmployeeWithholdingTax(GenJournalLine)` | Entry point for Employee WHT calculation from General Journal. Resolves WHT groups, evaluates thresholds, calculates amounts, creates WHT entries + G/L entries. |
| `ResolveWHTGroupComponents(WHTGroupCode): List of WHTPostingSetup` | Expands a WHT Group into ordered list of posting setup records. |
| `EvaluateThreshold(PostingSetup, EmployeeNo, Amount, PostingDate): Record WHTThresholdResult` | Evaluates threshold rules (Record/Document/Category/Total period) and returns whether WHT applies and the taxable amount. |
| `CalcGrossUpAmount(NetAmount, WHTPercent): Decimal` | Calculates gross amount from net: `Gross = Net / (1 - WHT%)`. |
| `CalcCompoundBase(ComponentOrder, PriorComponents, BaseAmount): Decimal` | Adjusts base for compound method by including/excluding prior component taxes. |
| `UpdateThresholdAccumulator(EmployeeNo, PostingSetup, BaseAmount, WHTAmount, PostingDate)` | Inserts/updates accumulator records after posting. |
| `ReverseThresholdAccumulator(EmployeeNo, PostingSetup, BaseAmount, WHTAmount, PostingDate)` | Decrements accumulators on reversal. |
| `GetPeriodBounds(PostingDate, ThresholdPeriod): (StartDate, EndDate)` | Returns period start/end based on Month/Quarter/Year/Fiscal. |
| `ShowWithholdingBreakdown(GenJournalLine)` | Preview action — calculates and displays WHT breakdown without posting. |

Modified procedures:

| Procedure | Change |
|---|---|
| `InsertWithholdingTax()` | Add branch for Party Type = Employee. Delegate to `InsertEmployeeWithholdingTax`. |
| `CheckWithholdingCalculationRule()` | Extend for new threshold bases (category/total period). |
| `NextEntryNo()` | No change needed (already generic). |
| `RoundWithholdingTaxAmount()` | No change needed (already generic). |

#### New Codeunit: `Wthldg Tax Employee Subscribers`

Event subscribers for Employee journal posting:

| Subscriber | Event | Logic |
|---|---|---|
| `OnAfterPostGenJnlLineEmployee` | Gen. Jnl. posting | Triggers `InsertEmployeeWithholdingTax` when Account Type = Employee |
| `OnBeforePostGenJnlLineEmployee` | Gen. Jnl. validation | Validates WHT setup exists for Employee + posting groups |
| `OnAfterReverseGenJnlLineEmployee` | Reversal posting | Creates reversing WHT entries + updates accumulators |

#### Codeunit 6792 `Wthldg Tax Preview Handler` — Modify

- Add support for previewing Employee WHT entries.

---

## 5. Calculation Logic

### 5.1 Simple Calculation (Gross Base)

```
WHT Amount = Base Amount × WHT %
Net Payable = Base Amount - WHT Amount
```

For each component independently.

### 5.2 Simple Calculation (Net / Gross-up Base)

```
Gross Amount = Net Amount / (1 - WHT %)
WHT Amount = Gross Amount × WHT % = Gross Amount - Net Amount
```

The employee receives `Net Amount`. The expense is `Gross Amount`. The WHT payable is `WHT Amount`.

### 5.3 Compound Calculation

Components are ordered by `Component Order`. For component $i$:

$$\text{Base}_i = \text{Base Amount} + \sum_{j \in \text{IncludedComponents}_i} \text{WHT Amount}_j$$

$$\text{WHT Amount}_i = \text{Base}_i \times \text{WHT \%}_i$$

The compound chain respects the `Compound Base Includes` configuration on WHT Group Lines.

### 5.4 Threshold Evaluation

| Threshold Base | Evaluation Logic |
|---|---|
| **Record/Line** | Compare journal line base amount vs threshold amount |
| **Document** | Sum all journal lines for same Document No., then compare |
| **Category in Period** | Query `WHT Threshold Accumulator` for Employee + Category + Period, add current line, compare |
| **Total in Period** | Query `WHT Threshold Accumulator` for Employee + Period (all categories), add current line, compare |

When threshold is exceeded:
- Default: WHT applies to **full amount** (not just the excess)
- Configurable: WHT applies only to **excess above threshold** (optional, future)

---

## 6. Posting Flow

### 6.1 General Journal → Employee WHT (End-to-End)

```
User enters General Journal Line:
  Account Type = Employee
  Employee No. = EMP001
  Amount = 5,000 (gross or net per setup)
  Posting Date = 2026-07-15
        │
        ▼
[1] Resolve WHT Bus. Post. Group from Employee Card
        │
        ▼
[2] Determine WHT Selection Mode
    ├── Single Tax → 1 Prod. Post. Group from expense/line
    └── Tax Group  → N Prod. Post. Groups from WHT Group Lines
        │
        ▼
[3] For each WHT Prod. Post. Group (ordered by Component Order):
    │
    ├── [3a] Get Withholding Tax Posting Setup (Bus × Prod)
    │
    ├── [3b] Evaluate Threshold
    │   ├── Record → Compare line amount
    │   ├── Document → Sum document lines
    │   ├── Category Period → Query accumulator + current
    │   └── Total Period → Query accumulator + current
    │
    ├── [3c] Calculate WHT Amount
    │   ├── Gross → Amount × WHT%
    │   ├── Net → Gross-up then Amount × WHT%
    │   └── Compound → Adjust base per prior components
    │
    └── [3d] Round WHT Amount
        │
        ▼
[4] Create Entries:
    ├── 1 × Employee Ledger Entry (transaction amount)
    ├── N × Withholding Tax Entry (one per component)
    │     linked to ELE via Employee Ledger Entry No.
    │     stores: Party Type, Employee No., Calc Base/Method,
    │             Threshold evaluation, Component Order
    └── G/L Entries:
          Debit:  Expense Account (gross amount)
          Credit: Bank/Bal Account (net payable to employee)
          Credit: WHT Payable Account 1 (component 1 amount)
          Credit: WHT Payable Account 2 (component 2 amount)
          ...
        │
        ▼
[5] Update Threshold Accumulators
        │
        ▼
[6] Done — entries are auditable and drillable
```

### 6.2 Reversal Flow

```
Reverse Transaction triggered
        │
        ▼
[1] Find original WHT Entries linked to ELE
        │
        ▼
[2] Create reversing WHT Entries (negated amounts)
    ├── Set "Reversed by Entry No." on original
    └── Set "Reversed Entry No." on new
        │
        ▼
[3] Reverse G/L Entries (standard BC reversal)
        │
        ▼
[4] Decrement Threshold Accumulators
        │
        ▼
[5] Done — audit trail intact
```

---

## 7. Data Architecture

```
                                    ┌──────────────────────────┐
                                    │   Expense Category       │
                                    │   (if used)              │
                                    │                          │
                                    │  WHT Selection Mode      │
                                    │  WHT Prod. Post. Group   │
                                    │  WHT Group Code          │
                                    └────────────┬─────────────┘
                                                 │
         ┌───────────────────┐                   │
         │    Employee       │                   ▼
         │                   │     ┌──────────────────────────┐
         │ WHT Bus. Post.    ├────►│ Withholding Tax          │
         │   Group           │     │ Posting Setup            │◄── WHT Prod. Post. Group
         │ WHT Certificate   │     │                          │
         │ Withholding       │     │ WHT %, Accounts,         │
         │   Exempt          │     │ Calc Base, Calc Method,  │
         └───────┬───────────┘     │ Threshold Base/Period    │
                 │                 └──────────────────────────┘
                 │                                │
                 ▼                                ▼
    ┌────────────────────┐       ┌──────────────────────────┐
    │ Employee Ledger    │       │ Withholding Tax Entry    │
    │ Entry              │◄──────│                          │
    │                    │       │ Party Type = Employee    │
    │ WHT Amount         │       │ Employee No.             │
    │ WHT Base Amount    │       │ ELE Entry No.            │
    └────────────────────┘       │ Calc Base, Calc Method   │
                                 │ Component Order          │
                                 │ Threshold evaluation     │
                                 │ Base, Amount, WHT %      │
                                 └──────────┬───────────────┘
                                            │
                                            ▼
                                 ┌──────────────────────────┐
                                 │ WHT Threshold            │
                                 │ Accumulator              │
                                 │                          │
                                 │ Employee + Category +    │
                                 │ Period → Running totals  │
                                 └──────────────────────────┘

    ┌──────────────────────────┐
    │ Withholding Tax Group    │
    │                          │
    │ Code, Description        │
    │ Party Applicability      │
    ├──────────────────────────┤
    │ Group Lines              │
    │ ├─ Prod. Post. Group 1   │
    │ │  Component Order: 1    │
    │ ├─ Prod. Post. Group 2   │
    │ │  Component Order: 2    │
    │ └─ Prod. Post. Group 3   │
    │    Component Order: 3    │
    └──────────────────────────┘
```

---

## 8. G/L Entry Examples

### 8.1 Simple Gross — Single Component

Employee payment of 10,000 with 15% WHT:

| G/L Account | Debit | Credit |
|---|---|---|
| Expense Account | 10,000 | |
| Bank Account | | 8,500 |
| WHT Payable | | 1,500 |

WHT Entry: Base = 10,000, Amount = 1,500, WHT% = 15

### 8.2 Net (Gross-up) — Single Component

Employee promised net 8,500 with 15% WHT:
- $\text{Gross} = 8{,}500 / (1 - 0.15) = 10{,}000$
- $\text{WHT} = 10{,}000 \times 0.15 = 1{,}500$

| G/L Account | Debit | Credit |
|---|---|---|
| Expense Account | 10,000 | |
| Bank Account | | 8,500 |
| WHT Payable | | 1,500 |

### 8.3 Multi-Component (Tax Group, Simple)

Employee payment of 10,000 with 3 components: Federal 10%, State 5%, Social 3%:

| G/L Account | Debit | Credit |
|---|---|---|
| Expense Account | 10,000 | |
| Bank Account | | 8,200 |
| WHT Payable — Federal | | 1,000 |
| WHT Payable — State | | 500 |
| WHT Payable — Social | | 300 |

3 WHT Entries created, all linked to same ELE.

### 8.4 Compound Calculation

Payment of 10,000. Federal 10% (order 1), State 5% (order 2, base includes Federal tax):

- Federal: $10{,}000 \times 10\% = 1{,}000$
- State base: $10{,}000 + 1{,}000 = 11{,}000$; State: $11{,}000 \times 5\% = 550$
- Total WHT: $1{,}550$

| G/L Account | Debit | Credit |
|---|---|---|
| Expense Account | 10,000 | |
| Bank Account | | 8,450 |
| WHT Payable — Federal | | 1,000 |
| WHT Payable — State | | 550 |

---

## 9. Permission Sets

### New Permission Set: Update existing sets

| Permission Set | Changes |
|---|---|
| `WHT - Admin` | Add RIMD for new tables: Withholding Tax Group, Group Line, Threshold Accumulator. Add RIMD for Employee table extension fields. |
| `WHT - Edit` | Add RIM for new tables. Add RI for Threshold Accumulator. |
| `WHT - Read` | Add R for new tables. |
| `WHT - Objects` | Add X for new codeunits. Add R for new tables and pages. |
| `d365 Basic WHT` | Extend for new object access. |
| `d365 Bus Full Access WHT` | Extend for new object access. |
| `d365 Read WHT` | Extend for new object access. |
| `d365 Team Member WHT` | Extend for new object access. |

---

## 10. Reporting

### New / Extended Reports

| Report | Description |
|---|---|
| **Employee WHT Summary** (new) | Employee-wise WHT summary for a period, grouped by jurisdiction/component. Filters: Employee No., Posting Date, Jurisdiction. |
| **WHT Liability Summary** (extend existing) | Add Employee entries to liability summary by payable account / jurisdiction. |
| **WHT Transaction List** (extend existing) | Add ELE link, threshold status columns to detailed transaction list. |

---

## 11. Events & Extensibility

### Published Events (to be added)

| Codeunit | Event | Purpose |
|---|---|---|
| `Withholding Tax Mgmt.` | `OnBeforeInsertEmployeeWHTEntry` | Allow subscribers to modify WHT entry before insert |
| `Withholding Tax Mgmt.` | `OnAfterInsertEmployeeWHTEntry` | Notify after WHT entry created |
| `Withholding Tax Mgmt.` | `OnBeforeEvaluateThreshold` | Allow custom threshold logic |
| `Withholding Tax Mgmt.` | `OnAfterCalcEmployeeWHTAmount` | Allow adjustment of calculated WHT amount |
| `Withholding Tax Mgmt.` | `OnBeforeUpdateAccumulator` | Allow custom accumulator logic |
| `Wthldg Tax Employee Subscribers` | `OnBeforeResolveWHTGroupComponents` | Allow custom group resolution |

---

## 12. Testing Strategy

### Unit Tests

| Test Area | Scenarios |
|---|---|
| **Setup validation** | Employee WHT Bus. Post. Group assignment; WHT Group creation with lines; Posting Setup with new fields |
| **Simple Gross calc** | Single component, verify Base × WHT% = Amount |
| **Net (gross-up) calc** | Verify Gross = Net / (1 - WHT%), bank = net, expense = gross |
| **Compound calc** | 2–3 components with ordering, verify base adjustments |
| **Threshold — Record** | Below threshold → no WHT; at/above threshold → WHT applies |
| **Threshold — Document** | Multiple lines, document total exceeds threshold |
| **Threshold — Category Period** | Accumulation across multiple postings in same period |
| **Threshold — Total Period** | Accumulation across all categories in period |
| **Multi-component** | WHT Group with 3 components → 1 ELE + 3 WHT entries |
| **Reversal** | Reverse posted entry → reversing WHT entries + accumulator decremented |
| **Exemption** | Employee marked exempt → no WHT calculated |
| **Rounding** | Currency precision respected per component |
| **Preview** | Show Withholding Breakdown without posting |

### Integration Tests

| Test Area | Scenarios |
|---|---|
| **End-to-end journal posting** | Full flow from journal line to ELE + WHT entries + G/L |
| **Navigate** | Navigate from Document No. shows WHT entries for Employee |
| **G/L Register** | WHT entries linked to G/L Register |
| **Reports** | Employee WHT summary produces correct dataset |

---

## 13. Migration & Upgrade Considerations

- **No data migration** required — Employee WHT is a new capability.
- Existing Vendor WHT entries remain unchanged — new `Party Type` field defaults to `Vendor` for backward compatibility.
- Existing `Withholding Tax Posting Setup` records default `Calculation Base` = Gross, `Calculation Method` = Simple, `Threshold Base` = Record (matching current behavior).
- Caption renames on existing fields (Calculation Rule → Threshold Type, Min. Inv. Amount → Threshold Amount) are cosmetic only and do not affect stored data.

---

## 14. Dependencies

| Dependency | Type | Notes |
|---|---|---|
| Base Application — Employee table | Table Extension | WHT fields on Employee card |
| Base Application — Employee Ledger Entry | Table Extension | WHT Amount/Base fields |
| Base Application — Gen. Journal Line | Existing extension (6793) | Already extends Gen. Jnl. Line with WHT fields |
| Base Application — General Journal posting events | Event Subscription | Post-posting hook for Employee account type |
| Withholding Tax app (self) | Internal | All new objects within same app |

---

## 15. Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| ID range exhaustion (6784–6813) | Must allocate new range | High | Request additional ID range early in development |
| Compound calculation edge cases (circular dependencies, rounding cascades) | Incorrect tax amounts | Medium | Validate component order is acyclic; define rounding per component; extensive test coverage |
| Threshold accumulator performance on large datasets | Slow posting | Low | SumIndexFields on accumulator table keys; period-bounded queries |
| Backward compatibility — existing Vendor WHT flow | Regression | Medium | Party Type defaults to Vendor; all existing code paths unchanged unless Party Type = Employee |
| Expense Category dependency | Blocked if Expense Categories not available in W1 | Medium | Clarify with PM whether Expense Category table exists or must be created |

---

## 16. Sample Data — PM Presentation

This section provides concrete sample records for **setup**, **master**, and **transactional data** covering all six primary scenarios from the workitem.

---

### 16.1 Setup Data

#### A) Withholding Tax Business Posting Groups

| Code | Description | Party Applicability | Jurisdiction Code | Default Certificate Type |
|---|---|---|---|---|
| `EMP-DOM` | Employee Domestic | Employee | `DOMESTIC` | `CERT-A` |
| `EMP-INTL` | Employee International | Employee | `INTL` | |
| `VEND-DOM` | Vendor Domestic *(existing)* | Vendor | `DOMESTIC` | |

#### B) Withholding Tax Product Posting Groups

| Code | Description |
|---|---|
| `FEDERAL` | Federal Income Tax |
| `STATE` | State Income Tax |
| `SOCIAL` | Social Insurance Contribution |
| `FLAT15` | Flat 15% Withholding *(single-tax scenarios)* |
| `TRAVEL` | Travel/Per Diem WHT |
| `BONUS` | Bonus/One-time Compensation WHT |

#### C) Withholding Tax Posting Setup

| WHT Bus. Post. Group | WHT Prod. Post. Group | WHT % | Calc Base | Calc Method | Prepaid WHT Acct | Payable WHT Acct | Threshold Type | Threshold Amount | Threshold Base | Threshold Period | Threshold Category |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `EMP-DOM` | `FEDERAL` | 10.00 | Gross | Simple | `2310` | `5410` | Greater than or equal to | 0.00 | Record | | |
| `EMP-DOM` | `STATE` | 5.00 | Gross | Simple | `2320` | `5420` | Greater than or equal to | 0.00 | Record | | |
| `EMP-DOM` | `SOCIAL` | 3.00 | Gross | Simple | `2330` | `5430` | Greater than or equal to | 0.00 | Record | | |
| `EMP-DOM` | `FLAT15` | 15.00 | Gross | Simple | `2310` | `5410` | Greater than or equal to | 0.00 | Record | | |
| `EMP-DOM` | `TRAVEL` | 20.00 | Gross | Simple | `2340` | `5440` | Greater than or equal to | 2,000.00 | Category Period | Month | `TRAVEL` |
| `EMP-DOM` | `BONUS` | 25.00 | Net | Simple | `2350` | `5450` | Greater than or equal to | 5,000.00 | Total Period | Year | |

> **G/L Account legend:**
> `2310–2350` = WHT Prepaid accounts, `5410–5450` = WHT Payable (liability) accounts,
> `6100` = Reimbursement Expense, `6200` = Travel Expense, `6300` = Compensation Expense,
> `1100` = Bank Account

#### D) Withholding Tax Posting Setup — Compound Scenario

| WHT Bus. Post. Group | WHT Prod. Post. Group | WHT % | Calc Base | Calc Method | Prepaid WHT Acct | Payable WHT Acct | Threshold Type | Threshold Amount | Threshold Base |
|---|---|---|---|---|---|---|---|---|---|
| `EMP-DOM` | `FEDERAL` | 10.00 | Gross | **Compound** | `2310` | `5410` | Greater than or equal to | 0.00 | Record |
| `EMP-DOM` | `STATE` | 5.00 | Gross | **Compound** | `2320` | `5420` | Greater than or equal to | 0.00 | Record |

#### E) Withholding Tax Groups (Multi-Component)

**Group: `EMP-MULTI-TAX`** — Employee Multi-Tax Group

| WHT Group Code | Description | Party Applicability |
|---|---|---|
| `EMP-MULTI-TAX` | Federal + State + Social | Employee |

**Group Lines:**

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

#### F) Withholding Tax Revenue Types

| Code | Description | Sequence |
|---|---|---|
| `REIMB` | Reimbursements | 1 |
| `TRAVEL` | Travel & Per Diem | 2 |
| `COMP` | Compensation & Bonuses | 3 |
| `OTHER` | Other Employee Payments | 4 |

#### G) Expense Categories (with WHT Selection)

| Code | Description | WHT Selection Mode | WHT Prod. Post. Group | WHT Group Code |
|---|---|---|---|---|
| `REIMBURSE` | Professional Svc Reimbursement | Single Tax | `FLAT15` | |
| `TRAVEL` | Travel & Per Diem | Single Tax | `TRAVEL` | |
| `PROJECT` | One-time Project Compensation | Tax Group | | `EMP-MULTI-TAX` |
| `BONUS` | Bonus Outside Payroll | Single Tax | `BONUS` | |
| `COMPOUND-PAY` | Payment with Compound WHT | Tax Group | | `EMP-COMPOUND` |

---

### 16.2 Master Data

#### A) Employees

| Employee No. | Name | WHT Bus. Post. Group | WHT Certificate No. | WHT Certificate Type | Withholding Exempt |
|---|---|---|---|---|---|
| `EMP001` | Sarah Johnson | `EMP-DOM` | `CERT-2026-001` | `CERT-A` | No |
| `EMP002` | Michael Chen | `EMP-DOM` | `CERT-2026-002` | `CERT-A` | No |
| `EMP003` | Lisa Martinez | `EMP-DOM` | | | **Yes** *(exempt)* |
| `EMP004` | James Wilson | `EMP-INTL` | `CERT-2026-004` | | No |

#### B) G/L Accounts (referenced in setup)

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

### 16.3 Transactional Data — Scenario Walkthroughs

---

#### Scenario 1: Employee Reimbursement with Single WHT Component

> **FR1, FR6 — Sarah (EMP001) submits a 10,000 professional services reimbursement.**
> Setup: Single Tax mode, Prod Group = `FLAT15`, 15% WHT, Gross base.

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

#### Scenario 2: Multi-Component WHT (Tax Group — Federal + State + Social)

> **FR2 — Michael (EMP002) receives a one-time project compensation of 20,000.**
> Setup: Tax Group `EMP-MULTI-TAX` with 3 components. Simple method, Gross base.

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

**Result — Withholding Tax Entries (3 entries, 1 ELE):**

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

#### Scenario 3: Net (Gross-up) Withholding

> **FR4 — Sarah (EMP001) is promised a net bonus of 7,500.**
> Setup: Single Tax `BONUS`, 25% WHT, **Net (Gross-up)** base.

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

$$\text{Gross} = \frac{7{,}500}{1 - 0.25} = \frac{7{,}500}{0.75} = 10{,}000.00$$

$$\text{WHT Amount} = 10{,}000.00 \times 25\% = 2{,}500.00$$

| Field | Value |
|---|---|
| Gross expense amount | 10,000.00 |
| WHT withheld | 2,500.00 |
| Net paid to employee | 7,500.00 |

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

#### Scenario 4: Travel Allowance Exceeding Threshold (Category in Period)

> **FR8 — Michael (EMP002) posts three travel claims in July 2026.**
> Setup: `TRAVEL`, 20% WHT, Threshold = 2,000 per month per category `TRAVEL`.
> WHT applies only when cumulative travel exceeds 2,000 in the month.

**Transaction sequence:**

| # | Date | Document No. | Description | Line Amount |
|---|---|---|---|---|
| 1 | 2026-07-05 | `EMP-JNL-0010` | Travel claim — week 1 | 800.00 |
| 2 | 2026-07-15 | `EMP-JNL-0011` | Travel claim — week 2 | 900.00 |
| 3 | 2026-07-25 | `EMP-JNL-0012` | Travel claim — week 3 | 1,500.00 |

**Threshold evaluation (cumulative):**

| Txn # | Line Amt | Cumulative (Category: TRAVEL, Period: July 2026) | Threshold (2,000) | WHT Applies? | Taxable Base | WHT (20%) |
|---|---|---|---|---|---|---|
| 1 | 800.00 | 800.00 | 2,000.00 | **No** — below threshold | 0.00 | 0.00 |
| 2 | 900.00 | 1,700.00 | 2,000.00 | **No** — below threshold | 0.00 | 0.00 |
| 3 | 1,500.00 | 3,200.00 | 2,000.00 | **Yes** — 3,200 ≥ 2,000 | 1,500.00 | 300.00 |

**Result — WHT Entries (only Txn #3 produces):**

| Entry No. | Employee No. | Document No. | Posting Date | WHT Prod. Post. Group | Base | Amount | Threshold Base | Threshold Exceeded | Period Start | Period End | Expense Category |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 5010 | `EMP002` | `EMP-JNL-0012` | 2026-07-25 | `TRAVEL` | 1,500.00 | 300.00 | Category Period | Yes | 2026-07-01 | 2026-07-31 | `TRAVEL` |

**Result — WHT Threshold Accumulator (after all 3 transactions):**

| Employee No. | WHT Bus. Group | WHT Prod. Group | Threshold Base | Period Start | Period End | Expense Category | Accum. Base Amount | Accum. WHT Amount |
|---|---|---|---|---|---|---|---|---|
| `EMP002` | `EMP-DOM` | `TRAVEL` | Category Period | 2026-07-01 | 2026-07-31 | `TRAVEL` | 3,200.00 | 300.00 |

**Result — G/L Entries for Txn #3 only:**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6200` | Travel Expense | 1,500.00 | |
| `1100` | Bank—Operating | | 1,200.00 |
| `5440` | WHT Payable—Travel | | 300.00 |

*(Txns #1 and #2 post normally: full debit to Travel Expense, full credit to Bank, zero WHT.)*

---

#### Scenario 5: Compound Calculation (Federal + State with Base Inclusion)

> **FR4, AC5 — EMP001 receives a 10,000 payment with compound WHT.**
> Setup: Group `EMP-COMPOUND`. Federal 10% (order 1), State 5% (order 2, base includes Federal).

**General Journal Line (input):**

| Field | Value |
|---|---|
| Posting Date | 2026-08-15 |
| Document No. | `EMP-JNL-0020` |
| Account Type | Employee |
| Account No. | `EMP001` |
| Amount | -10,000.00 |
| WHT Group Code | `EMP-COMPOUND` |

**Calculation:**

| Step | Component | Component Order | Base Calculation | Base | WHT % | WHT Amount |
|---|---|---|---|---|---|---|
| 1 | Federal | 1 | Original amount | 10,000.00 | 10% | 1,000.00 |
| 2 | State | 2 | Original + Federal WHT | 10,000.00 + 1,000.00 = **11,000.00** | 5% | 550.00 |
| | **Total** | | | | | **1,550.00** |

Net paid to employee: 10,000.00 − 1,550.00 = **8,450.00**

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

#### Scenario 6: Reversal / Correction

> **FR6, AC6 — Reverse Scenario 1 (EMP-JNL-0001) posted on 2026-07-15.**

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

**Original WHT Entry (updated):**

| Entry No. | ... | Reversed by Entry No. | Reversed |
|---|---|---|---|
| 5001 | *(unchanged other fields)* | 5030 | **Yes** |

**Result — Reversing G/L Entries:**

| G/L Account | Account Name | Debit | Credit |
|---|---|---|---|
| `6100` | Reimbursement Expense | | 10,000.00 |
| `1100` | Bank—Operating | 8,500.00 | |
| `5410` | WHT Payable—Federal | 1,500.00 | |

**Accumulator impact:** If Scenario 1 had contributed to any period accumulator, that accumulator is decremented by 10,000 base and 1,500 WHT.

---

#### Scenario 7: Exempt Employee — No WHT

> **FR1 — Lisa (EMP003) submits a 5,000 reimbursement. She is marked Withholding Exempt.**

**General Journal Line (input):**

| Field | Value |
|---|---|
| Posting Date | 2026-07-20 |
| Document No. | `EMP-JNL-0040` |
| Account Type | Employee |
| Account No. | `EMP003` |
| Amount | -5,000.00 |

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

### 16.4 Data Summary — Entry Counts by Scenario

| Scenario | Description | Employee Ledger Entries | WHT Entries | G/L Entries |
|---|---|---|---|---|
| 1 | Single WHT (Gross) | 1 | 1 | 3 |
| 2 | Multi-Component (Tax Group) | 1 | 3 | 5 |
| 3 | Net (Gross-up) | 1 | 1 | 3 |
| 4 | Threshold (3 txns) | 3 | 1 *(only txn 3)* | 9 *(3+3+3)* |
| 5 | Compound WHT | 1 | 2 | 4 |
| 6 | Reversal | 1 *(reversing)* | 1 *(reversing)* | 3 *(reversing)* |
| 7 | Exempt Employee | 1 | 0 | 2 |

---

### 16.5 Reporting Sample Output

#### Employee WHT Summary — July 2026

| Employee No. | Employee Name | Jurisdiction | WHT Component | Total Base | Total WHT | Period |
|---|---|---|---|---|---|---|
| `EMP001` | Sarah Johnson | DOMESTIC | FLAT15 (15%) | 10,000.00 | 1,500.00 | Jul 2026 |
| `EMP002` | Michael Chen | DOMESTIC | FEDERAL (10%) | 20,000.00 | 2,000.00 | Jul 2026 |
| `EMP002` | Michael Chen | DOMESTIC | STATE (5%) | 20,000.00 | 1,000.00 | Jul 2026 |
| `EMP002` | Michael Chen | DOMESTIC | SOCIAL (3%) | 20,000.00 | 600.00 | Jul 2026 |
| `EMP002` | Michael Chen | DOMESTIC | TRAVEL (20%) | 1,500.00 | 300.00 | Jul 2026 |

#### WHT Liability Summary — July 2026

| Payable G/L Account | Account Name | Jurisdiction | Total Liability |
|---|---|---|---|
| `5410` | WHT Payable—Federal | DOMESTIC | 3,500.00 |
| `5420` | WHT Payable—State | DOMESTIC | 1,000.00 |
| `5430` | WHT Payable—Social | DOMESTIC | 600.00 |
| `5440` | WHT Payable—Travel | DOMESTIC | 300.00 |
| | **Grand Total** | | **5,400.00** |

---

## 17. Open Questions

| # | Question | Status |
|---|---|---|
| 1 | What is the new ID range allocation for Employee WHT objects? | Open |
| 2 | Does the W1 base app already have an Expense Category table, or must this slice create one? | Open |
| 3 | Should `Transaction Type` option on WHT Entry be converted to an enum for extensibility? | Open |
| 4 | Is WHT for Employee realized immediately on posting (no unrealized/realized split like Vendor invoices)? | Open — likely yes, since there's no invoice→payment two-step for employees |
| 5 | Should the Withholding Tax Group be restricted to Employees, or also Vendors/Customers? | Open — spec says "Employee only" initially |
| 6 | Should the `Compound Base Includes` field use a more structured approach (e.g., a separate inclusion table) instead of comma-separated codes? | Open |
