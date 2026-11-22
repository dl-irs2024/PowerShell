# Quick Start Guide - Power Automate Failed Runs Inspector

Get up and running in minutes with this step-by-step guide.

## 5-Minute Setup

### Step 1: Open PowerShell
```powershell
# Press Windows Key + X, select "Windows PowerShell (Admin)"
# Or use Windows Terminal (recommended)
```

### Step 2: Navigate to Application Directory
```powershell
cd "C:\Davis\vibe\Power-Automate\WpfPowerAutomateFailedRuns"
```

### Step 3: Set Execution Policy (if needed)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### Step 4: Run the Application
```powershell
# Simulation mode (fastest - uses sample data)
.\WpfPowerAutomateFailedRuns.ps1

# Or Live mode (requires Power Automate modules)
.\WpfPowerAutomateFailedRuns.ps1 -Mode Live
```

✅ The WPF window should open in seconds!

---

## First Run Walkthrough

### 1. Understand the Tabs

The application has 5 main tabs:

| Tab | Purpose | Icon Color |
|-----|---------|-----------|
| **Workflows** | View and filter all workflows | Blue |
| **Run History** | Monitor execution history | Blue |
| **Code Review** | Automated code quality analysis | Yellow |
| **Export** | Export data in multiple formats | Green |
| **Settings** | Configure mode and modules | Blue |

### 2. Workflows Tab (First Look)

```
┌─────────────────────────────────────────┐
│ FILTERS                                  │
│ Environment: [All Environments] ▼       │
│ Owner: [All Owners] ▼                   │
│ Status: [All Status] ▼                  │
│ [Apply Filters]                          │
└─────────────────────────────────────────┘

SAMPLE DATA SHOWN:
- Workflow_1 (Production) - 100 runs, 5 failures
- Workflow_2 (Development) - 250 runs, 10 failures
- ... (15 total in simulation mode)
```

**Try This:**
1. Click on a workflow row to select it
2. Click "View Details" to see more information
3. Click "Code Review" to analyze the workflow

### 3. Run History Tab

Shows recent workflow executions with:
- Start and end times
- Execution status (Success, Failed, Running)
- Error codes and messages
- Trigger type (Manual, Automated, Scheduled)

**Try This:**
1. Set a date range with the date pickers
2. Click "Refresh" to load runs in that range
3. Look for failed runs (Status = "Failed")

### 4. Code Review Tab

Automatically analyzes workflows for:
- **Error Handling**: Does it handle errors properly?
- **Re-entrancy**: Can it run concurrently?
- **Owner Status**: Is the owner active?
- **Failure Patterns**: Any trends?
- **Age**: Is it outdated?

**Try This:**
1. Click on a workflow in the Workflows tab
2. Click "Code Review"
3. Review the findings and recommendations

### 5. Export Tab

Export your data in multiple formats:

```
Format Options:
○ CSV (Excel, databases)
○ TSV (Tab-separated)
○ HTML (Professional report)
○ Excel (XLSX with formatting)
○ Markdown (GitHub, documentation)

Content Selection:
☑ Workflows
☑ Run History
☐ Code Review
```

**Try This:**
1. Keep CSV selected (fastest)
2. Check "Workflows" and "Run History"
3. Click "Export Now"
4. Choose a save location
5. Open the CSV file in Excel

### 6. Settings Tab

Configure the application:

**Data Source:**
- Simulation Mode: Uses sample data (default)
- Live Mode: Connects to Power Automate

**Module Validation:**
- Automatic check on startup
- Manual validation available
- Required modules listed

---

## Common Tasks

### Task 1: Find All Failed Workflows

```
1. Go to "Workflows" tab
2. Set "Status" filter to "Failed"
3. Click "Apply Filters"
4. Review the filtered list
5. Click "Code Review" for each
```

### Task 2: Export Failure Report

```
1. Go to "Run History" tab
2. Set date range (last 7 days)
3. Click "Refresh"
4. Go to "Export" tab
5. Select "HTML" format
6. Check "Workflows" and "Run History"
7. Click "Export Now"
8. Save to your Documents folder
```

### Task 3: Restart Failed Workflows

```
1. Go to "Run History" tab
2. Find failed runs (Status = "Failed")
3. Click to select failed runs
4. Click "Restart Selected"
5. A restart script is generated
6. Script is saved to: %TEMP%\WorkflowRestartScripts\
7. Review the script before running
```

### Task 4: Analyze Workflow Dependencies

```
1. Click on a workflow in "Workflows" tab
2. Click "Dependencies"
3. View all Canvas Apps that use it
4. See SharePoint List triggers
5. Check dependent workflows
6. Review dependency health status
```

### Task 5: Review Code Quality

```
1. Select a workflow
2. Click "Code Review"
3. Review findings:
   - Error handling coverage
   - Re-entrancy capability
   - Owner status
   - Failure rates
   - Age and updates
4. Click "Code Review" tab to see full report
```

---

## Tips & Tricks

### 🎨 Color Meanings
- **Red (#FF6B6B)**: Errors, deletions, critical issues
- **Green (#51CF66)**: Success, create actions, recommendations
- **Blue (#74C0FC)**: Information, neutral actions
- **Yellow (#FFD93D)**: Warnings, cautions

### ⌨️ Keyboard Shortcuts
- `Ctrl+Q`: Quit application
- `Ctrl+E`: Export (from most tabs)
- `Ctrl+R`: Refresh data
- `Tab`: Navigate between filters

### 📊 Useful Export Combinations

**For Documentation:**
- Format: Markdown
- Content: Workflows + Run History
- Use: Include in team wiki

**For Analysis:**
- Format: Excel
- Content: All selections
- Use: Data analysis in pivot tables

**For Email Reports:**
- Format: HTML
- Content: Code Review
- Use: Send to stakeholders

### 🔄 Switching Modes

To switch from Simulation to Live:
1. Go to "Settings" tab
2. Select "Live Mode"
3. Click "Test Connection"
4. Enter Power Automate credentials
5. Click "Validate Modules"

---

## Troubleshooting Quick Fixes

### Application Won't Start
```powershell
# Check PowerShell version (needs 5.1+)
$PSVersionTable.PSVersion

# If too old, download from:
# https://github.com/PowerShell/PowerShell/releases
```

### WPF Window Blank or Won't Display
```powershell
# Run as Administrator
Start-Process powershell -Verb RunAs

# Then navigate to folder and run again
.\WpfPowerAutomateFailedRuns.ps1
```

### Module Not Found Errors
```powershell
# Install required modules
Install-Module Microsoft.PowerApps.Administration.PowerShell -Force

# If not found in PowerShell Gallery, check:
# - You're connected to internet
# - PowerShell execution policy allows downloads
```

### Export Location Issues
```powershell
# Default export location
$env:TEMP\PA_Exports\

# Change by modifying script or use OS file dialog
# when exporting through the UI
```

---

## Next Steps

After mastering the basics:

1. **Schedule Regular Reviews**
   - Run on Mondays
   - Review failed workflows
   - Export summaries

2. **Set Up Monitoring**
   - Export weekly reports
   - Track failure trends
   - Review aging workflows

3. **Automate Restarts**
   - Use generated restart scripts
   - Schedule via Windows Task Scheduler
   - Monitor restart logs

4. **Extend Features**
   - Add custom analysis rules
   - Integrate with your tools
   - Create custom reports

---

## Getting Help

### Within the Application
- Hover over labels for tooltips
- Status bar shows current operation
- Error messages are descriptive

### In PowerShell
```powershell
# View detailed help
Get-Help .\WpfPowerAutomateFailedRuns.ps1 -Detailed

# See examples
Get-Help .\WpfPowerAutomateFailedRuns.ps1 -Examples

# Get parameter information
Get-Help .\WpfPowerAutomateFailedRuns.ps1 -Parameter *
```

### Documentation Files
- `README.md` - Full feature reference
- `QUICK-START.md` - This guide
- Inline PowerShell comments in scripts

---

## Sample Workflow Actions

### In Simulation Mode

The app generates 15 sample workflows with:
- Realistic names (Process_1, Approval_2, etc.)
- Mixed environments (Production, Dev, Testing)
- Various owners
- 10 recent runs per workflow
- Some failures mixed in
- Random error codes

Perfect for learning without connecting to live systems!

### Live Mode Prerequisites

Before switching to Live Mode:
1. ✓ PowerShell 5.1+ installed
2. ✓ Power Automate modules installed
3. ✓ Power Automate account with environment access
4. ✓ Internet connectivity

---

## Common Scenarios

### Scenario 1: "My workflow is failing in production"
1. Go to Workflows tab, filter by Production environment
2. Find your workflow
3. Click Code Review
4. Check "Failure Rate Analysis"
5. Review recommendations
6. Go to Run History tab
7. Export last 24 hours of runs
8. Analyze error patterns

### Scenario 2: "I need to report on workflow health"
1. Go to Export tab
2. Select HTML format
3. Select all content
4. Click "Export Now"
5. Send the HTML file via email
6. Recipients can view in any browser

### Scenario 3: "Owner left the company"
1. Go to Code Review tab
2. Look for "Owner is no longer active"
3. Click Details
4. Identify workflows without active owners
5. Email affected workflows to manager
6. Plan ownership transfer

### Scenario 4: "Restarting failed runs manually"
1. Go to Run History tab
2. Filter by Status = Failed
3. Select failed runs
4. Click "Restart Selected"
5. Review generated restart script
6. Run the script when ready
7. Monitor the new run attempts

---

## Performance Tips

### For Large Environments (100+ workflows)
- Use filters before exporting
- Export one environment at a time
- Schedule exports during off-hours
- Increase application memory allocation

### For Detailed Analysis
- Code Review can take longer on large datasets
- Run during low-traffic periods
- Export to CSV for detailed spreadsheet analysis

---

## Ready to Go!

You should now be able to:
- ✅ Launch the application
- ✅ Navigate all tabs
- ✅ Filter and view workflows
- ✅ Export data
- ✅ Analyze code quality
- ✅ Identify and restart failures

**Next: Explore the full README.md for advanced features!**

---

## Quick Reference Card

```
MAIN TABS:
Workflows → View all workflows
Run History → See execution history
Code Review → Check quality & issues
Export → Save data to files
Settings → Configure app

QUICK ACTIONS:
Filter + View → Click Apply Filters
Export → Go to Export tab, pick format
Code Review → Select workflow, click Code Review
Restart Run → Go to Run History, select, click Restart

FILE LOCATIONS:
Sample Data: Simulation mode (built-in)
Exports: User selected during export
Restart Scripts: %TEMP%\WorkflowRestartScripts\
Logs: Status bar shows current operation
```

---

Happy automating! 🚀
