<#
.SYNOPSIS  WPF Rules Editor: browse, create, edit, clone, delete and validate rules stored as JSON; edit the editor / category / source registries.
.DESCRIPTION
  New-RulesEditorView returns a Grid that can be hosted as a tab or inside another WPF UI.
  Rules live in Rules\catalog.json and Rules\packs\*.json (add a pack file for a new rule category or workflow editor).
  Saving writes each rule back to the file it came from (a .bak copy is made) and can bump the catalog version.
.EXAMPLE  .\Show-RulesEditor.ps1
.EXAMPLE  .\Show-RulesEditor.ps1 -RulesPath D:\MyRules
#>
[CmdletBinding()]
param([string]$RulesPath, [switch]$NoShow)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
if (-not (Get-Module RulesEngine)) { Import-Module (Join-Path $PSScriptRoot 'RulesEngine.psm1') -Force }

function New-RulesEditorView {
    [CmdletBinding()]
    param([string]$RulesPath)
    $xaml = @'
<TabControl xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Margin="4">
 <TabItem Header="Rules">
  <Grid Margin="6">
   <Grid.ColumnDefinitions><ColumnDefinition Width="400"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
   <DockPanel Margin="0,0,8,0">
     <TextBox x:Name="Search" DockPanel.Dock="Top" ToolTip="Filter by id, name, category, editor"/>
     <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,4,0,4">
       <ComboBox x:Name="FilterEditor" Width="120"/><ComboBox x:Name="FilterCat" Width="140" Margin="4,0,0,0"/>
     </StackPanel>
     <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" Margin="0,6,0,0">
       <Button x:Name="NewBtn" Content="New" Padding="8,2"/><Button x:Name="CloneBtn" Content="Clone" Padding="8,2" Margin="4,0,0,0"/><Button x:Name="DeleteBtn" Content="Delete" Padding="8,2" Margin="4,0,0,0"/>
       <Button x:Name="SaveAllBtn" Content="Save catalog" Padding="8,2" Margin="12,0,0,0" FontWeight="Bold"/>
     </StackPanel>
     <DataGrid x:Name="RuleGrid" IsReadOnly="True" AutoGenerateColumns="False" SelectionMode="Single" GridLinesVisibility="Horizontal">
       <DataGrid.Columns>
         <DataGridCheckBoxColumn Header="On" Binding="{Binding enabled}" Width="30"/>
         <DataGridTextColumn Header="Id" Binding="{Binding ruleId}" Width="95"/>
         <DataGridTextColumn Header="Sev" Binding="{Binding severity}" Width="60"/>
         <DataGridTextColumn Header="Name" Binding="{Binding name}" Width="*"/>
       </DataGrid.Columns>
     </DataGrid>
   </DockPanel>
   <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto">
    <StackPanel x:Name="Form" IsEnabled="False">
     <Grid>
      <Grid.ColumnDefinitions><ColumnDefinition Width="140"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
      <Grid.RowDefinitions><RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
      <TextBlock Text="Rule ID" Margin="0,3"/><TextBox x:Name="fId" Grid.Column="1" Margin="0,2"/>
      <TextBlock Grid.Row="1" Text="Rule key" Margin="0,3"/><TextBox x:Name="fKey" Grid.Row="1" Grid.Column="1" Margin="0,2"/>
      <TextBlock Grid.Row="2" Text="Name" Margin="0,3"/><TextBox x:Name="fName" Grid.Row="2" Grid.Column="1" Margin="0,2"/>
      <TextBlock Grid.Row="3" Text="Version" Margin="0,3"/>
      <StackPanel Grid.Row="3" Grid.Column="1" Orientation="Horizontal" Margin="0,2"><TextBox x:Name="fVer" Width="80"/><CheckBox x:Name="fEnabled" Content="Enabled" Margin="12,0,0,0" VerticalAlignment="Center"/>
        <TextBlock Text="Severity" Margin="16,0,4,0" VerticalAlignment="Center"/><ComboBox x:Name="fSev" Width="90"/>
        <TextBlock Text="Mode" Margin="16,0,4,0" VerticalAlignment="Center"/><ComboBox x:Name="fMode" Width="90"/></StackPanel>
      <TextBlock Grid.Row="4" Text="Likelihood x Impact" Margin="0,3"/>
      <StackPanel Grid.Row="4" Grid.Column="1" Orientation="Horizontal" Margin="0,2"><ComboBox x:Name="fLik" Width="60"/><TextBlock Text=" x " VerticalAlignment="Center"/><ComboBox x:Name="fImp" Width="60"/><TextBlock x:Name="fRisk" Margin="12,0,0,0" VerticalAlignment="Center"/></StackPanel>
      <TextBlock Grid.Row="5" Text="Workflow editors" Margin="0,3"/><ListBox x:Name="fEditors" Grid.Row="5" Grid.Column="1" SelectionMode="Multiple" Height="80" Margin="0,2"/>
      <TextBlock Grid.Row="6" Text="Categories" Margin="0,3"/><ListBox x:Name="fCats" Grid.Row="6" Grid.Column="1" SelectionMode="Multiple" Height="110" Margin="0,2"/>
     </Grid>
     <Grid>
      <Grid.ColumnDefinitions><ColumnDefinition Width="140"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
      <Grid.RowDefinitions><RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
      <TextBlock Text="Applies to" Margin="0,3"/><ListBox x:Name="fApplies" Grid.Column="1" SelectionMode="Multiple" Height="100" Margin="0,2"/>
      <TextBlock Grid.Row="1" Text="Detector" Margin="0,3"/>
      <StackPanel Grid.Row="1" Grid.Column="1" Orientation="Horizontal" Margin="0,2"><ComboBox x:Name="fDetType" Width="150"/><TextBlock Text="Logic" Margin="10,0,4,0" VerticalAlignment="Center"/><ComboBox x:Name="fLogic" IsEditable="True" Width="260"/><TextBlock x:Name="fImpl" Margin="10,0,0,0" VerticalAlignment="Center" FontStyle="Italic"/></StackPanel>
      <TextBlock Grid.Row="2" Text="Detector params (JSON)" Margin="0,3"/><TextBox x:Name="fParams" Grid.Row="2" Grid.Column="1" Height="46" AcceptsReturn="True" FontFamily="Consolas" Margin="0,2"/>
      <TextBlock Grid.Row="3" Text="Message" Margin="0,3"/><TextBox x:Name="fMsg" Grid.Row="3" Grid.Column="1" TextWrapping="Wrap" AcceptsReturn="True" Height="46" Margin="0,2"/>
      <TextBlock Grid.Row="4" Text="Risk" Margin="0,3"/><TextBox x:Name="fRiskTxt" Grid.Row="4" Grid.Column="1" TextWrapping="Wrap" AcceptsReturn="True" Height="46" Margin="0,2"/>
      <TextBlock Grid.Row="5" Text="Remediation (one per line)" Margin="0,3" TextWrapping="Wrap"/><TextBox x:Name="fFix" Grid.Row="5" Grid.Column="1" AcceptsReturn="True" Height="66" Margin="0,2"/>
      <TextBlock Grid.Row="6" Text="Rule source" Margin="0,3"/>
      <StackPanel Grid.Row="6" Grid.Column="1" Margin="0,2">
        <ComboBox x:Name="fSrcPick" ToolTip="Pick a registered source (fills the fields below)"/>
        <Grid Margin="0,2"><Grid.ColumnDefinitions><ColumnDefinition Width="90"/><ColumnDefinition Width="110"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
          <TextBox x:Name="fSrcId" ToolTip="sourceId"/><TextBox x:Name="fSrcType" Grid.Column="1" ToolTip="type (Microsoft, Internal, Community...)" Margin="2,0"/><TextBox x:Name="fSrcName" Grid.Column="2" ToolTip="name"/></Grid>
        <TextBox x:Name="fSrcUrl" ToolTip="url (e.g. a learn.microsoft.com page)"/>
      </StackPanel>
      <TextBlock Grid.Row="7" Text="Validation" Margin="0,3"/>
      <StackPanel Grid.Row="7" Grid.Column="1" Margin="0,2">
        <StackPanel Orientation="Horizontal"><Button x:Name="ApplyBtn" Content="Apply to catalog" Padding="8,2"/><Button x:Name="TestBtn" Content="Test rule on sample..." Padding="8,2" Margin="6,0,0,0"/></StackPanel>
        <TextBlock x:Name="fStatus" TextWrapping="Wrap" Margin="0,4"/>
      </StackPanel>
     </Grid>
    </StackPanel>
   </ScrollViewer>
  </Grid>
 </TabItem>
 <TabItem Header="Registries">
  <DockPanel Margin="6">
   <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,6">
     <ComboBox x:Name="RegPick" Width="160"/><Button x:Name="RegSave" Content="Validate &amp; save" Padding="8,2" Margin="6,0,0,0"/>
     <TextBlock x:Name="RegStatus" Margin="10,0,0,0" VerticalAlignment="Center"/>
   </StackPanel>
   <TextBox x:Name="RegText" AcceptsReturn="True" AcceptsTab="True" FontFamily="Consolas" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"/>
  </DockPanel>
 </TabItem>
</TabControl>
'@
    $view = [Windows.Markup.XamlReader]::Parse($xaml)
    $c = @{ RulesPath = $RulesPath; Current = $null; Loading = $false }
    foreach ($n in 'Search', 'FilterEditor', 'FilterCat', 'NewBtn', 'CloneBtn', 'DeleteBtn', 'SaveAllBtn', 'RuleGrid', 'Form', 'fId', 'fKey', 'fName', 'fVer', 'fEnabled', 'fSev', 'fMode', 'fLik', 'fImp', 'fRisk', 'fEditors', 'fCats', 'fApplies', 'fDetType', 'fLogic', 'fImpl', 'fParams', 'fMsg', 'fRiskTxt', 'fFix', 'fSrcPick', 'fSrcId', 'fSrcType', 'fSrcName', 'fSrcUrl', 'ApplyBtn', 'TestBtn', 'fStatus', 'RegPick', 'RegSave', 'RegText', 'RegStatus') { $c[$n] = $view.FindName($n) }

    $loadRegistries = {
        $c.Catalog = Get-RuleCatalog -RulesPath $c.RulesPath
        $c.Editors = @(Get-RuleRegistry -Name editors -RulesPath $c.RulesPath)
        $c.Cats = @(Get-RuleRegistry -Name categories -RulesPath $c.RulesPath)
        $c.Sources = @(Get-RuleRegistry -Name sources -RulesPath $c.RulesPath)
        $c.Rules = New-Object System.Collections.ArrayList
        foreach ($r in $c.Catalog.Rules) { [void]$c.Rules.Add($r) }
    }.GetNewClosure()
    & $loadRegistries

    foreach ($s in 'Info', 'Warning', 'High', 'Critical') { [void]$c.fSev.Items.Add($s) }
    foreach ($m in 'Static', 'Hybrid', 'Runtime', 'Metadata') { [void]$c.fMode.Items.Add($m) }
    foreach ($i in 1..5) { [void]$c.fLik.Items.Add($i); [void]$c.fImp.Items.Add($i) }
    foreach ($t in 'DefinitionPattern', 'Expression', 'RuntimeMetric', 'Metadata', 'Custom') { [void]$c.fDetType.Items.Add($t) }
    $fillChecks = { param($lb, $values) $lb.Items.Clear(); foreach ($v in @($values)) { $cb = New-Object Windows.Controls.CheckBox; $cb.Content = [string]$v; [void]$lb.Items.Add($cb) } }
    & $fillChecks $c.fApplies @('Flow', 'Trigger', 'Action', 'Condition', 'Loop', 'Scope', 'Connector', 'Connection', 'Expression', 'ErrorHandling', 'Run', 'Runtime', 'Environment', 'Solution', 'DataSource')
    $c.fLogic.ItemsSource = @(Get-RuleLogic | ForEach-Object Name | Sort-Object)
    $c.FilterEditor.ItemsSource = @('(all editors)') + @($c.Editors | ForEach-Object id); $c.FilterEditor.SelectedIndex = 0
    $c.FilterCat.ItemsSource = @('(all categories)') + @($c.Cats | ForEach-Object id); $c.FilterCat.SelectedIndex = 0
    & $fillChecks $c.fEditors @($c.Editors | ForEach-Object id)
    & $fillChecks $c.fCats @($c.Cats | ForEach-Object id)
    $c.fSrcPick.ItemsSource = @($c.Sources | ForEach-Object { "$($_.id) - $($_.name)" })
    $c.RegPick.ItemsSource = @('editors', 'categories', 'sources'); 

    $refresh = {
        $q = $c.Search.Text.Trim().ToLower()
        $ed = if ($c.FilterEditor.SelectedIndex -gt 0) { [string]$c.FilterEditor.SelectedItem }
        $ct = if ($c.FilterCat.SelectedIndex -gt 0) { [string]$c.FilterCat.SelectedItem }
        $c.RuleGrid.ItemsSource = @($c.Rules | Where-Object {
                $hay = (@($_.ruleId, $_.name) + @($_.categories) + @($_.editors)) -join ' '
                (-not $q -or $hay.ToLower().Contains($q)) -and (-not $ed -or @($_.editors) -contains $ed) -and (-not $ct -or @($_.categories) -contains $ct)
            })
    }.GetNewClosure()
    $c.Refresh = $refresh

    $setSel = { param($lb, $values) $vals = @($values | ForEach-Object { [string]$_ }); foreach ($cb in $lb.Items) { $cb.IsChecked = ($vals -contains [string]$cb.Content) } }
    $getSel = { param($lb) @($lb.Items | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Content }) }
    $showRisk = {
        if ($c.fLik.SelectedItem -and $c.fImp.SelectedItem) {
            $s = [int]$c.fLik.SelectedItem * [int]$c.fImp.SelectedItem
            $g = if ($s -ge 20) { 'Critical' } elseif ($s -ge 15) { 'Very High' } elseif ($s -ge 10) { 'High' } elseif ($s -ge 5) { 'Moderate' } else { 'Low' }
            $c.fRisk.Text = "score $s ($g)"
        }
    }.GetNewClosure()
    $show = {
        param($r)
        $c.Loading = $true
        $c.Current = $r
        $c.Form.IsEnabled = [bool]$r
        if ($r) {
            $c.fId.Text = [string]$r.ruleId; $c.fKey.Text = [string]$r.ruleKey; $c.fName.Text = [string]$r.name; $c.fVer.Text = [string]$r.ruleVersion
            $c.fEnabled.IsChecked = [bool]$r.enabled; $c.fSev.SelectedItem = [string]$r.severity; $c.fMode.SelectedItem = [string]$r.inspectionMode
            $def = $c.DefImpact[[string]$r.severity]
            $c.fLik.SelectedItem = if ($r.likelihood) { [int]$r.likelihood } else { $def[0] }
            $c.fImp.SelectedItem = if ($r.impact) { [int]$r.impact } else { $def[1] }
            & $setSel $c.fEditors $r.editors; & $setSel $c.fCats $r.categories; & $setSel $c.fApplies $r.appliesTo
            $c.fDetType.SelectedItem = [string]$r.detector.type; $c.fLogic.Text = [string]$r.detector.logic
            $c.fParams.Text = if ($r.detector.params) { $r.detector.params | ConvertTo-Json -Depth 10 } else { '' }
            $c.fMsg.Text = [string]$r.message; $c.fRiskTxt.Text = [string]$r.risk; $c.fFix.Text = (@($r.remediation) -join "`r`n")
            $c.fSrcId.Text = [string]$r.source.sourceId; $c.fSrcType.Text = [string]$r.source.type; $c.fSrcName.Text = [string]$r.source.name; $c.fSrcUrl.Text = [string]$r.source.url
            $c.fImpl.Text = '[' + (Get-RuleImplementation -Rule $r) + ']'
            & $showRisk
        }
        $c.fStatus.Text = ''
        $c.Loading = $false
    }.GetNewClosure()
    $c.DefImpact = @{ Info = @(2, 1); Warning = @(3, 3); High = @(4, 3); Critical = @(4, 5) }

    # Build a rule object from the form, preserving unknown properties (documentation, etc.).
    $collect = {
        $r = $c.Current
        $o = [ordered]@{}
        foreach ($p in $r.PSObject.Properties) { $o[$p.Name] = $p.Value }
        $o.ruleId = $c.fId.Text.Trim(); $o.ruleKey = $c.fKey.Text.Trim(); $o.ruleVersion = $c.fVer.Text.Trim(); $o.name = $c.fName.Text.Trim()
        $o.enabled = [bool]$c.fEnabled.IsChecked; $o.severity = [string]$c.fSev.SelectedItem; $o.inspectionMode = [string]$c.fMode.SelectedItem
        $o.likelihood = [int]$c.fLik.SelectedItem; $o.impact = [int]$c.fImp.SelectedItem
        $o.editors = @(& $getSel $c.fEditors); $o.categories = @(& $getSel $c.fCats); $o.appliesTo = @(& $getSel $c.fApplies)
        $det = [ordered]@{ type = [string]$c.fDetType.SelectedItem; logic = $c.fLogic.Text.Trim() }
        if ($c.fParams.Text.Trim()) { $det.params = ($c.fParams.Text | ConvertFrom-Json) }
        $o.detector = [pscustomobject]$det
        $o.message = $c.fMsg.Text; $o.risk = $c.fRiskTxt.Text
        $o.remediation = @($c.fFix.Text -split "\r?\n" | Where-Object { $_.Trim() })
        $o.source = [pscustomobject]@{ sourceId = $c.fSrcId.Text.Trim(); type = $c.fSrcType.Text.Trim(); name = $c.fSrcName.Text.Trim(); url = $c.fSrcUrl.Text.Trim() }
        [pscustomobject]$o
    }.GetNewClosure()

    $c.Search.Add_TextChanged({ & $c.Refresh }.GetNewClosure())
    $c.FilterEditor.Add_SelectionChanged({ & $c.Refresh }.GetNewClosure())
    $c.FilterCat.Add_SelectionChanged({ & $c.Refresh }.GetNewClosure())
    $c.RuleGrid.Add_SelectionChanged({ if ($c.RuleGrid.SelectedItem) { & $show $c.RuleGrid.SelectedItem } }.GetNewClosure())
    $c.fLik.Add_SelectionChanged({ & $showRisk }.GetNewClosure()); $c.fImp.Add_SelectionChanged({ & $showRisk }.GetNewClosure())
    $c.fSrcPick.Add_SelectionChanged({
            $i = $c.fSrcPick.SelectedIndex; if ($i -lt 0 -or $c.Loading) { return }
            $s = $c.Sources[$i]; $c.fSrcId.Text = $s.id; $c.fSrcType.Text = $s.type; $c.fSrcName.Text = $s.name; $c.fSrcUrl.Text = $s.url
        }.GetNewClosure())

    $c.ApplyBtn.Add_Click({
            try {
                $new = & $collect
                $errs = @(Test-RuleDefinition -Rule $new)
                $dup = @($c.Rules | Where-Object { $_.ruleId -eq $new.ruleId -and $_ -ne $c.Current })
                if ($dup.Count) { $errs += "ruleId '$($new.ruleId)' already exists" }
                if ($errs.Count) { $c.fStatus.Foreground = 'Firebrick'; $c.fStatus.Text = ($errs -join "`r`n"); return }
                $i = $c.Rules.IndexOf($c.Current); if ($i -ge 0) { $c.Rules[$i] = $new } else { [void]$c.Rules.Add($new) }
                $c.Current = $new
                & $c.Refresh; $c.RuleGrid.SelectedItem = $new
                $c.fStatus.Foreground = 'DarkGreen'; $c.fStatus.Text = 'Valid. Applied in memory - press "Save catalog" to write the JSON file.'
            } catch { $c.fStatus.Foreground = 'Firebrick'; $c.fStatus.Text = $_.Exception.Message }
        }.GetNewClosure())

    $newRule = {
        param($tmpl)
        $o = [pscustomobject][ordered]@{ ruleId = 'XX-NEW-001'; ruleKey = 'new-rule'; ruleVersion = '1.0.0'; name = 'New rule'; enabled = $true; severity = 'Warning'; categories = @(); appliesTo = @('Action'); inspectionMode = 'Static'; editors = @('PowerAutomate'); detector = [pscustomobject]@{ type = 'DefinitionPattern'; logic = '' }; message = ''; risk = ''; remediation = @(); source = [pscustomobject]@{ sourceId = 'internal'; type = 'Internal'; name = ''; url = '' }; _file = $null }
        if ($tmpl) { $o = ($tmpl | ConvertTo-Json -Depth 20 | ConvertFrom-Json); $o.ruleId = "$($tmpl.ruleId)-COPY"; $o.ruleKey = "$($tmpl.ruleKey)-copy" }
        [void]$c.Rules.Add($o); & $c.Refresh; $c.RuleGrid.SelectedItem = $o
    }.GetNewClosure()
    $c.NewBtn.Add_Click({ & $newRule $null }.GetNewClosure())
    $c.CloneBtn.Add_Click({ if ($c.Current) { & $newRule $c.Current } }.GetNewClosure())
    $c.DeleteBtn.Add_Click({
            if (-not $c.Current) { return }
            if ([Windows.MessageBox]::Show("Delete rule $($c.Current.ruleId)?", 'Delete', 'YesNo', 'Question') -eq 'Yes') { $c.Rules.Remove($c.Current); & $show $null; & $c.Refresh }
        }.GetNewClosure())
    $c.SaveAllBtn.Add_Click({
            try {
                $bad = @($c.Rules | ForEach-Object { $e = @(Test-RuleDefinition -Rule $_); if ($e.Count) { "$($_.ruleId): $($e -join '; ')" } })
                if ($bad.Count) { [void][Windows.MessageBox]::Show(($bad -join "`n"), 'Fix these rules before saving'); return }
                $cat = [pscustomobject]@{ Version = $c.Catalog.Version; Folder = $c.Catalog.Folder; Files = $c.Catalog.Files; Rules = @($c.Rules) }
                Save-RuleCatalog -Catalog $cat -BumpVersion
                $c.fStatus.Foreground = 'DarkGreen'; $c.fStatus.Text = "Saved $($c.Rules.Count) rules to $($c.Catalog.Folder) (.bak copies made)."
            } catch { $c.fStatus.Foreground = 'Firebrick'; $c.fStatus.Text = $_.Exception.Message }
        }.GetNewClosure())
    $c.TestBtn.Add_Click({
            $d = New-Object Microsoft.Win32.OpenFileDialog; $d.Filter = 'Workflow JSON|*.json'
            $d.InitialDirectory = Join-Path (Split-Path (Get-Module RulesEngine).Path) 'Samples'
            if (-not $d.ShowDialog()) { return }
            try {
                $one = & $collect
                $cat = [pscustomobject]@{ Version = '0'; Folder = ''; Files = @(); Rules = @($one) }
                $rep = Invoke-WorkflowRules -Workflow (Import-Workflow -Path $d.FileName) -Catalog $cat
                $c.fStatus.Foreground = 'Black'
                $c.fStatus.Text = "Rule $($one.ruleId) on $([IO.Path]::GetFileName($d.FileName)): $($rep.summary.findingCount) finding(s)`r`n" + ((@($rep.findings | ForEach-Object { "- $($_.path): $($_.message)" }) + @($rep.notEvaluated | ForEach-Object { "- not evaluated: $($_.reason)" })) -join "`r`n")
            } catch { $c.fStatus.Foreground = 'Firebrick'; $c.fStatus.Text = $_.Exception.Message }
        }.GetNewClosure())

    $c.RegPick.Add_SelectionChanged({
            $f = Join-Path (Get-RulesFolder $c.RulesPath) ("$($c.RegPick.SelectedItem).json")
            $c.RegText.Text = Get-Content -LiteralPath $f -Raw -Encoding UTF8; $c.RegStatus.Text = $f
        }.GetNewClosure())
    $c.RegSave.Add_Click({
            try {
                $f = Join-Path (Get-RulesFolder $c.RulesPath) ("$($c.RegPick.SelectedItem).json")
                [void]($c.RegText.Text | ConvertFrom-Json)
                Copy-Item -LiteralPath $f -Destination "$f.bak" -Force
                [IO.File]::WriteAllText($f, $c.RegText.Text, (New-Object Text.UTF8Encoding($false)))
                $c.RegStatus.Text = "Saved $f. Reopen the editor to refresh pick-lists."
            } catch { $c.RegStatus.Text = "Invalid JSON: $($_.Exception.Message)" }
        }.GetNewClosure())

    & $c.Refresh
    $view.Tag = $c
    $view
}

if (-not $NoShow) {
    $w = New-Object Windows.Window
    $w.Title = 'Workflow Rules Editor'; $w.Width = 1300; $w.Height = 820
    $w.Content = New-RulesEditorView -RulesPath $RulesPath
    [void]$w.ShowDialog()
}
