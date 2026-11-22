# Power Automate Failed Runs Inspector

A comprehensive PowerShell WPF application for inspecting, analyzing, and managing Power Automate workflows and their execution history.

## Features

### 📊 Core Capabilities
- **Workflow Inspection**: View all published Power Automate workflows
- **Run History Tracking**: Monitor workflow executions with detailed status
- **Multi-format Export**: CSV, TSV, HTML, Excel, Markdown exports
- **Advanced Filtering**: Filter by date range, environment, owner, execution status
- **Code Review**: Automated analysis of best practices and potential issues
- **Dependency Analysis**: Identify Canvas Apps, SharePoint triggers, and workflow relationships
- **Workflow Restart**: Generate and execute restart scripts for failed workflows

### 🎨 User Interface
- **Multi-tab design** with pastel color scheme
  - **Red** (#FF6B6B): Delete or failure indicators
  - **Green** (#51CF66): Create or success actions
  - **Blue** (#74C0FC): Informational items
  - **Yellow** (#FFD93D): Warnings
- **Responsive WPF interface** with DataGrids and filters
- **Real-time status updates** in status bar
- **Professional HTML and Markdown reports**

### 🔍 Code Review Features
- **Re-entrancy Analysis**: Detect concurrent execution issues
- **Error Handling Detection**: Identify missing error handling logic
- **Owner Status Verification**: Flag inactive workflow owners
- **Failure Rate Analysis**: Trend analysis and alerting
- **Workflow Aging Detection**: Identify outdated workflows
- **Customizable Review Depths**: Full, Quick, or OnFailures

### 🔗 Dependency Detection
- **Canvas Apps**: Identify apps invoking the workflow
- **SharePoint Lists**: Find list triggers and relationships
- **Child Workflows**: Detect workflow-to-workflow dependencies
- **Dependency Health**: Monitor status of all dependencies
- **Impact Analysis**: Understand workflow relationships

### 🚀 Workflow Management
- **Dynamic Restart Scripts**: Auto-generated timestamped restart scripts
- **Retry Logic**: Configurable retry attempts and wait times
- **Comprehensive Logging**: Detailed execution logs for each restart
- **Error Reporting**: Detailed error messages and diagnostics

### 📋 Modes
- **Simulation Mode**: Test with realistic sample data (default)
- **Live Mode**: Connect to actual Power Automate environment
- **Module Validation**: Automatic validation of required modules

## Prerequisites

### System Requirements
- Windows 7 or later
- PowerShell 5.1 or higher
- .NET Framework 4.5+

### Required PowerShell Modules (for Live mode)
```powershell
Install-Module Microsoft.PowerApps.Administration.PowerShell -Force
Install-Module Microsoft.PowerApps.PowerShell -Force
```

### Optional PowerShell Modules
```powershell
Install-Module ImportExcel -Force  # For Excel export support
```

## Installation

1. **Clone or download** the repository to your local machine:
```powershell
git clone <repository-url>
cd WpfPowerAutomateFailedRuns
```

2. **Review the scripts** (they are not signed, so adjust execution policy if needed):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

3. **Run the application**:
```powershell
.\WpfPowerAutomateFailedRuns.ps1
```

## Quick Start

### Simulation Mode (Default)
```powershell
.\WpfPowerAutomateFailedRuns.ps1 -Mode Simulation
```
This generates 15 sample workflows with realistic run history.

### Live Mode
```powershell
.\WpfPowerAutomateFailedRuns.ps1 -Mode Live
```
Connects to your actual Power Automate environment.

### Skip Module Validation
```powershell
.\WpfPowerAutomateFailedRuns.ps1 -SkipModuleValidation
```

## Usage Guide

### Workflows Tab
1. **View Workflows**: Browse all published workflows
2. **Filter by Environment**: Select environment from dropdown
3. **Filter by Owner**: Find workflows by creator/owner
4. **Filter by Status**: Show only failed, successful, or running workflows
5. **View Details**: Click "View Details" for detailed information
6. **Code Review**: Run automated code analysis
7. **Dependencies**: Check workflow relationships and dependencies

### Run History Tab
1. **Select Date Range**: Use date pickers to filter by date
2. **View Runs**: See all workflow executions
3. **Filter by Status**: Show only failed runs
4. **Restart Failed Runs**: Select runs and click "Restart Selected"
5. **Export Data**: Export run history in multiple formats
6. **Refresh**: Update with latest data

### Code Review Tab
Automatic analysis results showing:
- **Critical Issues**: Requires urgent attention (Red)
- **Warnings**: Should be reviewed (Yellow)
- **Info**: Informational findings (Blue)
- **Success**: Best practices detected (Green)

Analysis includes:
- Error handling coverage
- Re-entrancy compatibility
- Owner status
- Failure rate trends
- Workflow age assessment

### Dependency Tab
View all workflow dependencies:
- **Canvas Apps** invoking the workflow
- **SharePoint Lists** triggering the workflow
- **Child Workflows** called by this workflow
- **Dependent Workflows** that call this workflow
- **Health Status** of each dependency

### Export Tab
1. **Select Format**:
   - CSV: Comma-separated values (Excel-compatible)
   - TSV: Tab-separated values
   - HTML: Styled HTML report
   - Excel: XLSX format (if ImportExcel installed)
   - Markdown: GitHub-compatible markdown

2. **Choose Content**:
   - Workflows: Workflow list and details
   - Run History: Execution history
   - Code Review: Analysis findings

3. **Export**: Click "Export Now" and select location

### Settings Tab
- **Data Source**: Switch between Simulation and Live modes
- **Test Connection**: Validate Power Automate connectivity
- **Module Validation**: Check required modules
- **Version Information**: View app details

## Advanced Features

### Code Review Analysis

The code review performs multiple checks:

```
1. Owner Status Check
   - Identifies inactive owners
   - Flags workflows at risk

2. Error Handling Detection
   - Checks for try-catch blocks
   - Recommends improvements

3. Re-entrancy Analysis
   - Detects concurrent execution issues
   - Provides guidelines for safe re-entrancy

4. Failure Rate Analysis
   - Categorizes failure rates
   - Provides trend analysis
   - Triggers alerts for high failure rates

5. Workflow Age Assessment
   - Identifies aging workflows
   - Recommends updates
```

### Workflow Restart

The restart feature:
1. Generates a unique, timestamped script
2. Includes retry logic with configurable attempts
3. Provides comprehensive logging
4. Supports both single and batch restarts
5. Includes detailed error reporting

Generated scripts are saved to: `$env:TEMP\WorkflowRestartScripts\`

Example script name: `Restart-Workflow_SampleWorkflow_20240115_143025.ps1`

### Export Formats

**CSV/TSV**
- Compatible with Excel
- Easy to import into databases
- Minimal formatting

**HTML**
- Professional styling
- Color-coded severity indicators
- Sortable tables
- Shareable via email

**Excel**
- Multiple sheets (if supported)
- Formatted cells
- Freeze panes for headers
- Requires ImportExcel module

**Markdown**
- GitHub and Azure DevOps compatible
- Easy to include in documentation
- Version control friendly

## Configuration

### Pastel Color Palette
- **Delete (Red)**: `#FF6B6B` - Destructive or error actions
- **Create (Green)**: `#51CF66` - Constructive or success actions
- **Info (Blue)**: `#74C0FC` - Informational or neutral items
- **Warning (Yellow)**: `#FFD93D` - Warnings or cautions
- **Neutral (Light Gray)**: `#F8F9FA` - Background
- **Text (Dark Gray)**: `#2C3E50` - Primary text

### Module Cache Location
Sample data and cache files are stored in: `$env:TEMP\PAFailedRunsCache\`

## Troubleshooting

### Module Import Errors
```powershell
# Update modules
Update-Module Microsoft.PowerApps.Administration.PowerShell -Force
Update-Module Microsoft.PowerApps.PowerShell -Force

# Or reinstall
Remove-Module Microsoft.PowerApps.Administration.PowerShell
Install-Module Microsoft.PowerApps.Administration.PowerShell -Force
```

### WPF Display Issues
- Ensure .NET Framework 4.5+ is installed
- Try running in administrator mode
- Check Windows display scaling settings

### Live Mode Connection Fails
1. Verify module installation: `Get-Module -ListAvailable | grep PowerApps`
2. Test authentication: `Add-PowerAppsAccount`
3. Check environment access: `Get-AdminPowerAppEnvironment`

### Export Fails
- Verify write permissions to destination folder
- Check disk space
- For Excel export, install ImportExcel module

## File Structure

```
WpfPowerAutomateFailedRuns/
├── WpfPowerAutomateFailedRuns.ps1          # Main WPF application
├── Export-WorkflowData.ps1                 # Export functionality module
├── New-WorkflowRestartScript.ps1          # Restart script generator
├── Invoke-CodeReview.ps1                   # Code review and analysis
├── Get-WorkflowDependencies.ps1           # Dependency analysis
├── README.md                               # This file
├── QUICK-START.md                          # Quick start guide
└── LICENSE                                 # License file
```

## Extending the Application

### Adding New Analysis Rules
Edit `Invoke-CodeReview.ps1` and add new `Test-Workflow*` functions:

```powershell
function Test-WorkflowCustomRule {
    param([PSCustomObject]$Workflow)
    
    $findings = @()
    # Your analysis logic here
    return $findings
}
```

### Adding New Export Formats
Edit `Export-WorkflowData.ps1` and add new `Export-To*` functions:

```powershell
function Export-ToJSON {
    param([object[]]$Data, [string]$OutputPath)
    # JSON export logic
}
```

### Custom Data Sources
Modify the data retrieval logic in `WpfPowerAutomateFailedRuns.ps1`:
- `Get-SampleData` function for simulation mode
- `Get-LiveData` function for live mode

## Future Enhancements

Planned features for future versions:
- **Power Apps Canvas Integration**: View Canvas Apps and their dependencies
- **SharePoint List Explorer**: Manage SharePoint List connections
- **Azure AD Integration**: User profile and licensing information
- **Multi-tenant Support**: Manage workflows across tenants
- **Webhook Monitoring**: Track webhook-based triggers
- **Performance Metrics**: Detailed performance analytics
- **Custom Alerts**: Define custom alert rules
- **Scheduled Reports**: Automated report generation
- **API Integration**: REST API for programmatic access

## License

This project is provided as-is for Power Automate management and inspection.

## Support

For issues, feature requests, or questions:
1. Check existing documentation
2. Review troubleshooting section
3. Consult PowerShell event logs: `Get-WinEvent -LogName 'Windows PowerShell'`

## Version History

### v1.0.0 (Initial Release)
- Core WPF interface
- Workflow inspection and filtering
- Run history tracking
- Multi-format export (CSV, TSV, HTML, Excel, Markdown)
- Code review and analysis
- Workflow dependency detection
- Restart script generation
- Simulation and Live modes
- Comprehensive documentation

---

**Happy workflow automation!** 🚀

For the latest updates and information, visit the project repository.
