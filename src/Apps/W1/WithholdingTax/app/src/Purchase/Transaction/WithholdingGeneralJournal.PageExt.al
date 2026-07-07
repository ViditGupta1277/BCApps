// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.WithholdingTax;

using Microsoft.Finance.GeneralLedger.Journal;

pageextension 6801 "Withholding General Journal" extends "General Journal"
{
    layout
    {
        // Add changes to page layout here
        addbefore("Bal. Gen. Posting Type")
        {
            field("Expense Category"; Rec."Expense Category")
            {
                ApplicationArea = Basic, Suite;
                ToolTip = 'Specifies the expense category for the general journal line.';
            }
        }
    }
}