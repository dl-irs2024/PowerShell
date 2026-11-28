<#
.SYNOPSIS  WPF Rules Tester: drop a workflow JSON, load a URL, paste JSON, or run Simulation mode (problem/model pairs and generated defects).
.DESCRIPTION
  New-RulesTesterView returns a Grid that can be hosted as a tab or inside another WPF UI.
  Running this script directly opens it in its own window.
.EXAMPLE  .\Show-RulesTester.ps1
.EXAMPLE  $tab.Content = New-RulesTesterView   # after dot-sourcing
#>
[CmdletBinding()]
param([switch]$NoShow)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
if (-not (Get-Module RulesEngine)) { Import-Module (Join-Path $PSScriptRoot 'RulesEngine.psm1') -Force }
$Script:TesterRoot = $PSScriptRoot

function New-RulesTesterView {
    [CmdletBinding()]
    param([string]$RulesPath)
    $xaml = @'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Margin="8">
  <Grid.ColumnDefinitions><ColumnDefinition Width="340"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
  <DockPanel Grid.Column="0" Margin="0,0,8,0" LastChildFill="True">
    <Border x:Name="DropZone" DockPanel.Dock="Top" Height="130" AllowDrop="True" BorderBrush="#FF3B82F6" BorderThickness="2" CornerRadius="6" Background="#FFEFF6FF">
      <TextBlock x:Name="DropText" Text="Drop workflow JSON / ZIP files here" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="14" Foreground="#FF1D4ED8" TextWrapping="Wrap" TextAlignment="Center"/>
    </Border>
    <Button x:Name="BrowseBtn" DockPanel.Dock="Top" Content="Browse..." Margin="0,6,0,0" Padding="4"/>
    <TextBlock DockPanel.Dock="Top" Text="Or load from URL" Margin="0,8,0,2"/>
    <DockPanel DockPanel.Dock="Top"><Button x:Name="UrlBtn" DockPanel.Dock="Right" Content="Load" Padding="8,2" Margin="4,0,0,0"/><TextBox x:Name="UrlBox"/></DockPanel>
    <TextBlock DockPanel.Dock="Top" Text="Bearer token (optional, for URL)" Margin="0,6,0,2"/>
    <PasswordBox x:Name="TokenBox" DockPanel.Dock="Top"/>
    <Expander DockPanel.Dock="Top" Header="Filters" Margin="0,8,0,0" IsExpanded="True">
      <StackPanel>
        <TextBlock Text="Workflow editor"/><ComboBox x:Name="EditorBox"/>
        <TextBlock Text="Minimum severity" Margin="0,4,0,0"/><ComboBox x:Name="SevBox"/>
        <TextBlock Text="Category" Margin="0,4,0,0"/><ComboBox x:Name="CatBox"/>
      </StackPanel>
    </Expander>
    <CheckBox x:Name="SimBox" DockPanel.Dock="Top" Content="Simulation mode" FontWeight="Bold" Margin="0,10,0,4"/>
    <StackPanel x:Name="SimPanel" DockPanel.Dock="Top" Visibility="Collapsed">
      <TextBlock Text="Problem / Model pairs"/>
      <ListBox x:Name="PairList" Height="110" DisplayMemberPath="Title"/>
      <StackPanel Orientation="Horizontal" Margin="0,4,0,0"><Button x:Name="RunProblem" Content="Run problem" Padding="6,2"/><Button x:Name="RunModel" Content="Run model" Padding="6,2" Margin="4,0,0,0"/><Button x:Name="RunCompare" Content="Compare" Padding="6,2" Margin="4,0,0,0"/></StackPanel>
      <TextBlock Text="Generate defects on the model" Margin="0,8,0,2"/>
      <ListBox x:Name="DefectList" Height="110" SelectionMode="Multiple" DisplayMemberPath="Description"/>
      <Button x:Name="GenBtn" Content="Generate &amp; run" Margin="0,4,0,0" Padding="4"/>
      <Button x:Name="SaveGenBtn" Content="Save generated JSON..." Margin="0,4,0,0" Padding="4"/>
    </StackPanel>
    <TextBox x:Name="PasteBox" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" ToolTip="Paste workflow JSON here and press Run" Margin="0,8,0,0" MinHeight="60"/>
  </DockPanel>
  <DockPanel Grid.Column="1">
    <TextBlock x:Name="Summary" DockPanel.Dock="Top" FontSize="14" FontWeight="SemiBold" Text="No workflow loaded." TextWrapping="Wrap"/>
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,6,0,6">
      <Button x:Name="RunPaste" Content="Run pasted JSON" Padding="8,2"/>
      <TextBlock Text="Export:" VerticalAlignment="Center" Margin="12,0,4,0"/>
      <ComboBox x:Name="FmtBox" Width="90"/>
      <Button x:Name="ExportBtn" Content="Export..." Padding="8,2" Margin="4,0,0,0"/>
      <Button x:Name="ExprBtn" Content="Expression inspector" Padding="8,2" Margin="12,0,0,0"/>
    </StackPanel>
    <TabControl>
      <TabItem Header="Findings">
        <DockPanel>
          <TextBox x:Name="Detail" DockPanel.Dock="Bottom" Height="130" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
          <DataGrid x:Name="Grid" IsReadOnly="True" AutoGenerateColumns="False" SelectionMode="Single" GridLinesVisibility="Horizontal">
            <DataGrid.Columns>
              <DataGridTextColumn Header="Severity" Binding="{Binding severity}" Width="70"/>
              <DataGridTextColumn Header="Rule" Binding="{Binding ruleId}" Width="100"/>
              <DataGridTextColumn Header="Risk" Binding="{Binding riskScore}" Width="45"/>
              <DataGridTextColumn Header="Where" Binding="{Binding path}" Width="200"/>
              <DataGridTextColumn Header="Message" Binding="{Binding message}" Width="*"/>
            </DataGrid.Columns>
          </DataGrid>
        </DockPanel>
      </TabItem>
      <TabItem Header="Expressions"><DataGrid x:Name="ExprGrid" IsReadOnly="True" AutoGenerateColumns="True"/></TabItem>
      <TabItem Header="Comparison"><TextBox x:Name="CompareBox" IsReadOnly="True" FontFamily="Consolas" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/></TabItem>
      <TabItem Header="Not evaluated"><DataGrid x:Name="NotEvalGrid" IsReadOnly="True" AutoGenerateColumns="True"/></TabItem>
    </TabControl>
  </DockPanel>
</Grid>
'@
    $view = [Windows.Markup.XamlReader]::Parse($xaml)
    $c = @{}
    foreach ($n in 'DropZone', 'DropText', 'BrowseBtn', 'UrlBtn', 'UrlBox', 'TokenBox', 'EditorBox', 'SevBox', 'CatBox', 'SimBox', 'SimPanel', 'PairList', 'RunProblem', 'RunModel', 'RunCompare', 'DefectList', 'GenBtn', 'SaveGenBtn', 'PasteBox', 'Summary', 'RunPaste', 'FmtBox', 'ExportBtn', 'ExprBtn', 'Grid', 'Detail', 'ExprGrid', 'CompareBox', 'NotEvalGrid') { $c[$n] = $view.FindName($n) }
    $c.RulesPath = $RulesPath
    $c.Workflow = $null; $c.Report = $null; $c.GeneratedJson = $null

    $reg = Get-RuleRegistry -Name editors -RulesPath $RulesPath
    $cats = Get-RuleRegistry -Name categories -RulesPath $RulesPath
    [void]$c.EditorBox.Items.Add('(auto / all)'); foreach ($e in $reg) { [void]$c.EditorBox.Items.Add($e.id) }; $c.EditorBox.SelectedIndex = 0
    foreach ($s in '(any)', 'Info', 'Warning', 'High', 'Critical') { [void]$c.SevBox.Items.Add($s) }; $c.SevBox.SelectedIndex = 0
    [void]$c.CatBox.Items.Add('(all)'); foreach ($k in $cats) { [void]$c.CatBox.Items.Add($(if ($k.name) { $k.name } else { $k.id })) }; $c.CatBox.SelectedIndex = 0
    foreach ($f in 'Json', 'Html', 'Markdown', 'Csv', 'Excel', 'Word', 'Pdf') { [void]$c.FmtBox.Items.Add($f) }; $c.FmtBox.SelectedIndex = 1
    $c.PairList.ItemsSource = @(Get-SamplePairs); $c.DefectList.ItemsSource = @(Get-SimulationDefects)

    $run = {
        param($wf, [string]$label)
        try {
            $p = @{ Workflow = $wf; RulesPath = $c.RulesPath }
            if ($c.EditorBox.SelectedIndex -gt 0) { $p.Editor = [string]$c.EditorBox.SelectedItem }
            if ($c.SevBox.SelectedIndex -gt 0) { $p.MinSeverity = [string]$c.SevBox.SelectedItem }
            if ($c.CatBox.SelectedIndex -gt 0) { $p.Category = [string]$c.CatBox.SelectedItem }
            $r = Invoke-WorkflowRules @p
            $c.Workflow = $wf; $c.Report = $r
            $s = $r.summary
            $c.Summary.Text = "{0} | {1} | editor {2} | health {3}/100 | risk {4} | {5} findings (C{6} H{7} W{8} I{9})" -f $label, $r.reportId, $r.workflow.editor, $s.healthScore, $s.overallRisk, $s.findingCount, $s.bySeverity.Critical, $s.bySeverity.High, $s.bySeverity.Warning, $s.bySeverity.Info
            $c.Grid.ItemsSource = @($r.findings)
            $c.NotEvalGrid.ItemsSource = @($r.notEvaluated | ForEach-Object { [pscustomobject]@{ RuleId = $_.ruleId; Reason = $_.reason } })
            $c.ExprGrid.ItemsSource = @(Get-WdlExpressionMap -Workflow $wf)
            $c.Detail.Text = ''
        } catch { $c.Summary.Text = "Error: $($_.Exception.Message)" }
    }.GetNewClosure()
    $c.Run = $run
    $loadPath = { param($path) & $c.Run (Import-Workflow -Path $path) ([IO.Path]::GetFileName($path)) }.GetNewClosure()
    $safe = { param($sb) try { & $sb } catch { $c.Summary.Text = "Error: $($_.Exception.Message)" } }.GetNewClosure()

    $c.DropZone.Add_DragOver({ param($s, $e) $e.Effects = [Windows.DragDropEffects]::Copy; $e.Handled = $true })
    $c.DropZone.Add_DragEnter({ param($s, $e) $s.Background = [Windows.Media.Brushes]::LightCyan }.GetNewClosure())
    $c.DropZone.Add_DragLeave({ param($s, $e) $s.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFEFF6FF') })
    $c.DropZone.Add_Drop({
            param($s, $e)
            $s.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFEFF6FF')
            $files = @($e.Data.GetData([Windows.DataFormats]::FileDrop))
            if ($files.Count) { & $safe { & $loadPath $files[0] }; if ($files.Count -gt 1) { $c.Summary.Text += "  (first of $($files.Count) files)" } }
        }.GetNewClosure())
    $c.BrowseBtn.Add_Click({
            $d = New-Object Microsoft.Win32.OpenFileDialog; $d.Filter = 'Workflow (*.json;*.zip)|*.json;*.zip|All|*.*'
            if ($d.ShowDialog()) { & $safe { & $loadPath $d.FileName } }
        }.GetNewClosure())
    $c.UrlBtn.Add_Click({
            & $safe {
                $p = @{ Url = $c.UrlBox.Text.Trim() }; if ($c.TokenBox.Password) { $p.Token = $c.TokenBox.Password }
                & $c.Run (Import-Workflow @p) $p.Url
            }
        }.GetNewClosure())
    $c.RunPaste.Add_Click({ & $safe { & $c.Run (Import-Workflow -Json $c.PasteBox.Text) 'pasted JSON' } }.GetNewClosure())
    $c.SimBox.Add_Checked({ $c.SimPanel.Visibility = 'Visible' }.GetNewClosure())
    $c.SimBox.Add_Unchecked({ $c.SimPanel.Visibility = 'Collapsed' }.GetNewClosure())
    $c.RunProblem.Add_Click({ if ($c.PairList.SelectedItem) { & $safe { & $loadPath $c.PairList.SelectedItem.ProblemPath } } }.GetNewClosure())
    $c.RunModel.Add_Click({ $p = $c.PairList.SelectedItem; if ($p -and $p.ModelPath) { & $safe { & $loadPath $p.ModelPath } } }.GetNewClosure())
    $c.RunCompare.Add_Click({
            $p = $c.PairList.SelectedItem; if (-not $p) { return }
            & $safe {
                $x = Compare-SamplePair -Pair $p -RulesPath $c.RulesPath
                & $c.Run (Import-Workflow -Path $p.ProblemPath) "$($p.Title) (problem)"
                $lines = @("PAIR $($p.Id) - $($p.Title)", '',
                    ('Problem: health {0}, {1} findings' -f $x.Problem.summary.healthScore, $x.Problem.summary.findingCount),
                    ('Model  : health {0}, {1} findings' -f $x.Model.summary.healthScore, $x.Model.summary.findingCount), '', 'Rules fixed by the model workflow:')
                foreach ($id in $x.Fixed) { $lines += "  - $id  " + (@($x.Problem.findings | Where-Object ruleId -eq $id)[0].name) }
                if ($x.Remaining.Count) { $lines += ''; $lines += 'Still reported on the model: ' + ($x.Remaining -join ', ') }
                $c.CompareBox.Text = $lines -join "`r`n"
            }
        }.GetNewClosure())
    $c.GenBtn.Add_Click({
            $p = $c.PairList.SelectedItem; $sel = @($c.DefectList.SelectedItems)
            if (-not $p -or -not $sel.Count) { $c.Summary.Text = 'Select a pair and at least one defect.'; return }
            & $safe {
                $base = if ($p.ModelPath) { $p.ModelPath } else { $p.ProblemPath }
                $ids = @($sel | ForEach-Object Id)
                $c.GeneratedJson = New-SimulatedWorkflow -Path $base -Defect $ids -AsJson
                & $c.Run (Import-Workflow -Json $c.GeneratedJson) ("generated: " + ($ids -join '+'))
            }
        }.GetNewClosure())
    $c.SaveGenBtn.Add_Click({
            if (-not $c.GeneratedJson) { return }
            $d = New-Object Microsoft.Win32.SaveFileDialog; $d.Filter = 'JSON|*.json'; $d.FileName = 'generated-workflow.json'
            if ($d.ShowDialog()) { [IO.File]::WriteAllText($d.FileName, $c.GeneratedJson) }
        }.GetNewClosure())
    $c.Grid.Add_SelectionChanged({
            $f = $c.Grid.SelectedItem; if (-not $f) { return }
            $c.Detail.Text = "$($f.ruleId) - $($f.name)  [$($f.severity), risk $($f.riskScore) $($f.riskGrade)]`r`n$($f.message)`r`nEvidence: $($f.evidence)`r`nRisk: $($f.risk)`r`nRemediation:`r`n  - " + (@($f.remediation) -join "`r`n  - ") + "`r`nSource: $($f.source.name) $($f.source.url)"
        }.GetNewClosure())
    $c.ExportBtn.Add_Click({
            if (-not $c.Report) { return }
            Add-Type -AssemblyName System.Windows.Forms
            $d = New-Object System.Windows.Forms.FolderBrowserDialog
            if ($d.ShowDialog() -eq 'OK') { & $safe { $o = Export-RulesReport -Report $c.Report -Format ([string]$c.FmtBox.SelectedItem) -OutDir $d.SelectedPath; $c.Summary.Text = "Wrote $o" } }
        }.GetNewClosure())
    $c.ExprBtn.Add_Click({ if ($c.Workflow) { $c.ExprGrid.ItemsSource = @(Get-WdlExpressionMap -Workflow $c.Workflow) } }.GetNewClosure())
    $view.Tag = $c
    $view
}

if (-not $NoShow) {
    $w = New-Object Windows.Window
    $w.Title = 'Workflow Rules Tester'; $w.Width = 1200; $w.Height = 760
    $w.Content = New-RulesTesterView
    [void]$w.ShowDialog()
}
