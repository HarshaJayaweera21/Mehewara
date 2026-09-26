using System.ComponentModel.DataAnnotations;

namespace Mehewara.API.DTOs.WorkOrders;

public class CompleteWorkOrderRequest
{
    [Required(ErrorMessage = "Completion notes are required to document field remediation.")]
    [StringLength(2000, MinimumLength = 3, ErrorMessage = "Completion notes must be between 3 and 2000 characters.")]
    public string CompletionNotes { get; set; } = string.Empty;
}

public class ReportWorkOrderIssueRequest
{
    [Required(ErrorMessage = "A reason for reporting an issue or cancelling work is required.")]
    [StringLength(2000, MinimumLength = 3, ErrorMessage = "Reason must be between 3 and 2000 characters.")]
    public string Reason { get; set; } = string.Empty;

    /// <summary>
    /// Can be 'FAIL' or 'CANCEL' (defaults to 'FAIL')
    /// </summary>
    public string Action { get; set; } = "FAIL";
}
