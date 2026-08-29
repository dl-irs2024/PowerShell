<#
.SYNOPSIS
Vibe Mermaid Render Editor (PowerShell 5.1 + WPF)

.DESCRIPTION
MVP editor and preview tool for text-based diagram/render formats:
- Mermaid
- SVG
- HTML

This script provides:
- Split-pane text editor + render preview
- Auto-render with debounce
- Open/save by format
- Preview export to standalone HTML
- Status and error surface

NOTES
- Mermaid preview uses a CDN script in the WPF WebBrowser preview pane.
- The WPF WebBrowser control is IE-based; Mermaid compatibility depends on engine policy.
- For production/stable Mermaid exports, consider Mermaid CLI render-to-SVG.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Web

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="Vibe Mermaid Render Editor"
		Height="900"
		Width="1500"
		WindowStartupLocation="CenterScreen"
		Background="#0F172A"
		Foreground="#E2E8F0"
		FontFamily="Segoe UI">
	<Grid Margin="12">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<Border Grid.Row="0" CornerRadius="10" Padding="10" Margin="0,0,0,10" Background="#111827" BorderBrush="#334155" BorderThickness="1">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="180"/>
					<ColumnDefinition Width="10"/>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="90"/>
					<ColumnDefinition Width="90"/>
					<ColumnDefinition Width="90"/>
					<ColumnDefinition Width="90"/>
					<ColumnDefinition Width="90"/>
					<ColumnDefinition Width="130"/>
					<ColumnDefinition Width="85"/>
					<ColumnDefinition Width="85"/>
					<ColumnDefinition Width="*"/>
				</Grid.ColumnDefinitions>

				<TextBlock Grid.Column="0" VerticalAlignment="Center" Margin="0,0,6,0" Text="Format:"/>
				<ComboBox Grid.Column="1" Name="FormatCombo" SelectedIndex="0" VerticalContentAlignment="Center" ToolTip="Select source format for rendering.">
					<ComboBoxItem Content="Mermaid"/>
					<ComboBoxItem Content="SVG"/>
					<ComboBoxItem Content="HTML"/>
				</ComboBox>

				<Button Grid.Column="3" Name="NewButton" Content="New" Margin="8,0,6,0" ToolTip="Create a new document from format template."/>
				<Button Grid.Column="4" Name="OpenButton" Content="Open" Margin="0,0,6,0" ToolTip="Open source text file."/>
				<Button Grid.Column="5" Name="SaveButton" Content="Save" Margin="0,0,6,0" ToolTip="Save source text file."/>
				<Button Grid.Column="6" Name="RenderButton" Content="Render" Margin="0,0,6,0" ToolTip="Render preview now."/>
				<Button Grid.Column="7" Name="ExportHtmlButton" Content="Export HTML" Margin="0,0,6,0" ToolTip="Export standalone preview HTML file."/>
				<Button Grid.Column="8" Name="TestButton" Content="Self Test" Margin="0,0,6,0" ToolTip="Load a known-good sample and render it."/>
				<CheckBox Grid.Column="9" Name="AutoRenderCheck" IsChecked="True" VerticalAlignment="Center" Content="Auto Render" ToolTip="Auto render after typing pauses."/>
				<Button Grid.Column="10" Name="PreviewZoomInButton" Content="Preview +" Margin="8,0,6,0" ToolTip="Zoom in preview (Mermaid/SVG wrappers)."/>
				<Button Grid.Column="11" Name="PreviewZoomOutButton" Content="Preview -" Margin="0,0,6,0" ToolTip="Zoom out preview (Mermaid/SVG wrappers)."/>
			</Grid>
		</Border>

		<Grid Grid.Row="1">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="1.2*"/>
				<ColumnDefinition Width="8"/>
				<ColumnDefinition Width="1*"/>
			</Grid.ColumnDefinitions>

			<Border Grid.Column="0" CornerRadius="10" Padding="8" Background="#111827" BorderBrush="#334155" BorderThickness="1">
				<Grid>
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="220"/>
					</Grid.RowDefinitions>
					<TextBlock Text="Source Editor" FontWeight="SemiBold" Margin="4,2,4,8"/>
					<TextBox Name="SourceEditor"
							 Grid.Row="1"
							 AcceptsReturn="True"
							 AcceptsTab="True"
							 TextWrapping="NoWrap"
							 VerticalScrollBarVisibility="Auto"
							 HorizontalScrollBarVisibility="Auto"
							 FontFamily="Consolas"
							 FontSize="14"
							 Background="#0B1220"
							 Foreground="#E2E8F0"
							 BorderBrush="#334155"
							 BorderThickness="1"
							 Padding="8"
							 ToolTip="Edit Mermaid, SVG, or HTML source text."/>
					<TextBlock Grid.Row="2" Text="Sample Library (click a row to load and render)" FontWeight="SemiBold" Margin="4,10,4,8"/>
					<DataGrid Name="SampleGrid"
							  Grid.Row="3"
							  AutoGenerateColumns="False"
							  HeadersVisibility="Column"
							  CanUserAddRows="False"
							  CanUserDeleteRows="False"
							  IsReadOnly="True"
							  SelectionMode="Single"
							  SelectionUnit="FullRow"
							  EnableRowVirtualization="True"
							  Background="#0B1220"
							  Foreground="#E2E8F0"
							  RowBackground="#111827"
							  AlternatingRowBackground="#1E293B"
							  AlternationCount="2"
							  BorderBrush="#334155"
							  BorderThickness="1"
							  ToolTip="Select a sample to load into editor and render.">
						<DataGrid.ColumnHeaderStyle>
							<Style TargetType="DataGridColumnHeader">
								<Setter Property="Background" Value="#0F172A"/>
								<Setter Property="Foreground" Value="#F8FAFC"/>
								<Setter Property="FontWeight" Value="SemiBold"/>
								<Setter Property="BorderBrush" Value="#334155"/>
								<Setter Property="BorderThickness" Value="0,0,0,1"/>
							</Style>
						</DataGrid.ColumnHeaderStyle>
						<DataGrid.RowStyle>
							<Style TargetType="DataGridRow">
								<Setter Property="Foreground" Value="#F8FAFC"/>
								<Style.Triggers>
									<Trigger Property="IsSelected" Value="True">
										<Setter Property="Background" Value="#1D4ED8"/>
										<Setter Property="Foreground" Value="#FFFFFF"/>
									</Trigger>
								</Style.Triggers>
							</Style>
						</DataGrid.RowStyle>
						<DataGrid.Columns>
							<DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="170"/>
							<DataGridTextColumn Header="Description" Binding="{Binding Description}" Width="*"/>
							<DataGridTextColumn Header="Format" Binding="{Binding Format}" Width="90"/>
						</DataGrid.Columns>
					</DataGrid>
				</Grid>
			</Border>

			<GridSplitter Grid.Column="1" Width="8" HorizontalAlignment="Stretch" Background="#1F2937"/>

			<Border Grid.Column="2" CornerRadius="10" Padding="8" Background="#111827" BorderBrush="#334155" BorderThickness="1">
				<Grid>
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
						<RowDefinition Height="130"/>
					</Grid.RowDefinitions>
					<TextBlock Text="Preview" FontWeight="SemiBold" Margin="4,2,4,8"/>
					<WebBrowser Name="PreviewBrowser" Grid.Row="1"/>
					<TextBox Name="ErrorBox"
							 Grid.Row="2"
							 Margin="0,8,0,0"
							 IsReadOnly="True"
							 FontSize="15"
							 FontWeight="SemiBold"
							 TextWrapping="Wrap"
							 VerticalScrollBarVisibility="Auto"
							 Background="#0B1220"
							 Foreground="#FCA5A5"
							 BorderBrush="#7F1D1D"
							 BorderThickness="1"
							 Padding="8"
							 ToolTip="Rendering/validation diagnostics."/>
				</Grid>
			</Border>
		</Grid>

		<StatusBar Grid.Row="2" Name="MainStatusBar" Background="#0F172A" Foreground="#E2E8F0" BorderBrush="#334155" BorderThickness="1,1,1,0" Margin="0,10,0,0">
			<StatusBarItem>
				<TextBlock Name="StatusText" Text="Ready"/>
			</StatusBarItem>
			<Separator/>
			<StatusBarItem>
				<TextBlock Name="RenderInfoText" Text="Format: Mermaid"/>
			</StatusBarItem>
		</StatusBar>
	</Grid>
</Window>
"@

[xml]$xamlXml = $xaml
$reader = New-Object System.Xml.XmlNodeReader($xamlXml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$controls = @{}
@(
	'FormatCombo', 'NewButton', 'OpenButton', 'SaveButton', 'RenderButton', 'ExportHtmlButton',
	'TestButton', 'PreviewZoomInButton', 'PreviewZoomOutButton',
	'AutoRenderCheck', 'SourceEditor', 'SampleGrid', 'PreviewBrowser', 'ErrorBox', 'StatusText', 'RenderInfoText'
) | ForEach-Object {
	$controls[$_] = $window.FindName($_)
}

$script:currentFilePath = ''
$script:lastPreviewHtml = ''
$script:autoRenderDelayMs = 550
$script:krokiBaseUrl = if ($env:KROKI_BASE_URL) { $env:KROKI_BASE_URL.TrimEnd('/') } else { 'https://kroki.io' }
$script:sampleItems = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
$script:previewZoom = 1.0

function Set-StatusText {
	param([string]$Message)
	$controls['StatusText'].Text = $Message
}

function Set-ErrorText {
	param([string]$Message)
	$controls['ErrorBox'].Text = $Message
}

function Get-SelectedFormat {
	$item = $controls['FormatCombo'].SelectedItem
	if (-not $item) { return 'Mermaid' }
	[string]$item.Content
}

function Get-DefaultExtensionForFormat {
	param([string]$Format)

	switch ($Format) {
		'Mermaid' { '.mmd' }
		'SVG' { '.svg' }
		'HTML' { '.html' }
		default { '.txt' }
	}
}

function Get-SampleSource {
	param([string]$Format)

	switch ($Format) {
		'Mermaid' {
@"
flowchart LR
	M[Mermaid] --> L[Logo]
	L --> R[Renderer]
	R --> P[Preview]
	style M fill:#22c55e,stroke:#14532d,color:#ffffff
	style L fill:#38bdf8,stroke:#0c4a6e,color:#ffffff
	style R fill:#f59e0b,stroke:#7c2d12,color:#111827
	style P fill:#a78bfa,stroke:#4c1d95,color:#ffffff
"@
		}
		'SVG' {
@"
<svg xmlns="http://www.w3.org/2000/svg" width="760" height="320" viewBox="0 0 760 320">
  <rect x="0" y="0" width="760" height="320" fill="#0B1220" />
  <rect x="28" y="28" width="704" height="264" rx="16" fill="#111827" stroke="#334155" stroke-width="2"/>
  <text x="58" y="86" fill="#93C5FD" font-size="30" font-family="Segoe UI">SVG Live Preview</text>
  <circle cx="102" cy="188" r="30" fill="#22C55E"/>
  <line x1="132" y1="188" x2="286" y2="188" stroke="#38BDF8" stroke-width="6"/>
  <rect x="300" y="156" width="180" height="64" rx="8" fill="#1E293B" stroke="#60A5FA"/>
  <text x="322" y="196" fill="#E2E8F0" font-size="20" font-family="Segoe UI">Editable SVG</text>
</svg>
"@
		}
		'HTML' {
@"
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <style>
	body { font-family: Segoe UI, Arial, sans-serif; margin: 16px; background: #0B1220; color: #E2E8F0; }
	.panel { border: 1px solid #334155; border-radius: 10px; padding: 14px; background: #111827; }
	h2 { color: #93C5FD; margin-top: 0; }
  </style>
</head>
<body>
  <div class="panel">
	<h2>HTML Preview Mode</h2>
	<p>Edit this HTML in the left pane and click <strong>Render</strong>.</p>
  </div>
</body>
</html>
"@
		}
		default { '' }
	}
}

function Get-SampleLibrary {
	@(
		[pscustomobject]@{
			Name = 'Flowchart - Pipeline'
			Description = 'Basic Mermaid flowchart with styled nodes.'
			Format = 'Mermaid'
			Source = @"
flowchart LR
		A[Source] --> B[Transform]
		B --> C[Validate]
		C --> D[Publish]
		style A fill:#22c55e,stroke:#14532d,color:#ffffff
		style B fill:#38bdf8,stroke:#0c4a6e,color:#ffffff
		style C fill:#f59e0b,stroke:#7c2d12,color:#111827
		style D fill:#a78bfa,stroke:#4c1d95,color:#ffffff
"@
		}
		[pscustomobject]@{
			Name = 'Flowchart - Neon Branches'
			Description = 'Colorful Mermaid flowchart with multiple paths and styling.'
			Format = 'Mermaid'
			Source = @"
flowchart TD
		S([Start]) --> A{Priority}
		A -->|High| B[Fast Track]
		A -->|Normal| C[Standard Queue]
		A -->|Low| D[Backlog]
		B --> X[Notify Team]
		C --> X
		D --> X
		X --> E([Done])
		style S fill:#10b981,stroke:#064e3b,color:#ffffff
		style A fill:#0ea5e9,stroke:#075985,color:#ffffff
		style B fill:#f43f5e,stroke:#881337,color:#ffffff
		style C fill:#f59e0b,stroke:#78350f,color:#111827
		style D fill:#8b5cf6,stroke:#4c1d95,color:#ffffff
		style X fill:#22d3ee,stroke:#0e7490,color:#082f49
		style E fill:#34d399,stroke:#065f46,color:#064e3b
"@
		}
		[pscustomobject]@{
			Name = 'Flowchart - Subgraph Effects'
			Description = 'Mermaid subgraphs with visual styling.'
			Format = 'Mermaid'
			Source = @"
flowchart LR
		subgraph Ingest
			A[CSV] --> B[Parser]
		end
		subgraph Process
			B --> C[Rules]
			C --> D[Enrichment]
		end
		subgraph Output
			D --> E[Warehouse]
			D --> F[Dashboard]
		end
		style A fill:#38bdf8,stroke:#075985,color:#082f49
		style B fill:#67e8f9,stroke:#0e7490,color:#083344
		style C fill:#fbbf24,stroke:#92400e,color:#111827
		style D fill:#f472b6,stroke:#9d174d,color:#ffffff
		style E fill:#34d399,stroke:#065f46,color:#064e3b
		style F fill:#a78bfa,stroke:#4c1d95,color:#ffffff
"@
		}
		[pscustomobject]@{
			Name = 'Venn Diagram'
			Description = 'SVG-based editable Venn sample.'
			Format = 'SVG'
			Source = @"
<svg xmlns="http://www.w3.org/2000/svg" width="760" height="300" viewBox="0 0 760 300">
	<rect width="760" height="300" fill="#0B1220" />
	<circle cx="310" cy="150" r="110" fill="#38BDF8" fill-opacity="0.45" stroke="#38BDF8" stroke-width="3"/>
	<circle cx="430" cy="150" r="110" fill="#F59E0B" fill-opacity="0.45" stroke="#F59E0B" stroke-width="3"/>
	<text x="235" y="70" fill="#E2E8F0" font-size="20" font-family="Segoe UI">Team A</text>
	<text x="445" y="70" fill="#E2E8F0" font-size="20" font-family="Segoe UI">Team B</text>
	<text x="353" y="155" fill="#FFFFFF" font-size="18" font-family="Segoe UI">Shared</text>
</svg>
"@
		}
		[pscustomobject]@{
			Name = 'Database Schema - Small'
			Description = 'Small Mermaid ER diagram for an order system.'
			Format = 'Mermaid'
			Source = @"
erDiagram
		CUSTOMER ||--o{ ORDER : places
		ORDER ||--|{ ORDER_ITEM : contains
		PRODUCT ||--o{ ORDER_ITEM : referenced_by

		CUSTOMER {
			int customer_id PK
			string name
			string email
		}
		ORDER {
			int order_id PK
			date order_date
			int customer_id FK
		}
		ORDER_ITEM {
			int order_item_id PK
			int order_id FK
			int product_id FK
			int qty
		}
		PRODUCT {
			int product_id PK
			string sku
			string title
		}
"@
		}
		[pscustomobject]@{
			Name = 'Database Schema - Medium'
			Description = 'Medium ER diagram with more entities and relationships.'
			Format = 'Mermaid'
			Source = @"
erDiagram
		CUSTOMER ||--o{ ORDER : places
		ORDER ||--|{ ORDER_ITEM : contains
		PRODUCT ||--o{ ORDER_ITEM : referenced_by
		SUPPLIER ||--o{ PRODUCT : supplies
		ORDER ||--|| PAYMENT : settled_by
		ORDER ||--o{ SHIPMENT : fulfilled_by
		WAREHOUSE ||--o{ SHIPMENT : dispatches

		CUSTOMER {
			int customer_id PK
			string name
			string email
			string segment
		}
		ORDER {
			int order_id PK
			date order_date
			int customer_id FK
			string status
		}
		ORDER_ITEM {
			int order_item_id PK
			int order_id FK
			int product_id FK
			int qty
			decimal unit_price
		}
		PRODUCT {
			int product_id PK
			string sku
			string title
			decimal price
		}
		SUPPLIER {
			int supplier_id PK
			string supplier_name
			string country
		}
		PAYMENT {
			int payment_id PK
			int order_id FK
			string method
			decimal amount
		}
		SHIPMENT {
			int shipment_id PK
			int order_id FK
			int warehouse_id FK
			string carrier
			string tracking
		}
		WAREHOUSE {
			int warehouse_id PK
			string city
			string zone
		}
"@
		}
		[pscustomobject]@{
			Name = 'Database Schema - Large'
			Description = 'Large ER diagram intended to force horizontal/vertical preview scrolling.'
			Format = 'Mermaid'
			Source = @"
erDiagram
		TENANT ||--o{ USER_ACCOUNT : owns
		TENANT ||--o{ PROJECT : hosts
		PROJECT ||--o{ EPIC : groups
		EPIC ||--o{ STORY : contains
		STORY ||--o{ TASK : decomposes
		TASK ||--o{ TASK_COMMENT : has
		TASK ||--o{ TASK_ATTACHMENT : has
		TASK ||--o{ TASK_TAG : tagged
		TAG ||--o{ TASK_TAG : maps
		USER_ACCOUNT ||--o{ TASK : assigned
		USER_ACCOUNT ||--o{ TASK_COMMENT : writes
		SPRINT ||--o{ TASK : schedules
		PROJECT ||--o{ SPRINT : plans
		PROJECT ||--o{ RELEASE : publishes
		RELEASE ||--o{ CHANGE_LOG : includes
		ENVIRONMENT ||--o{ DEPLOYMENT : target
		RELEASE ||--o{ DEPLOYMENT : triggers
		SERVICE ||--o{ DEPLOYMENT : deployed
		SERVICE ||--o{ INCIDENT : impacted
		INCIDENT ||--o{ INCIDENT_EVENT : timeline
		INCIDENT ||--o{ RCA_ITEM : root_cause
		USER_ACCOUNT ||--o{ INCIDENT : oncall
		PROJECT ||--o{ API_CLIENT : authorizes
		API_CLIENT ||--o{ API_TOKEN : issues
		AUDIT_LOG ||--|| USER_ACCOUNT : actor
		AUDIT_LOG ||--|| TENANT : scoped

		TENANT {
			int tenant_id PK
			string tenant_name
			string region
			string plan
		}
		USER_ACCOUNT {
			int user_id PK
			int tenant_id FK
			string upn
			string display_name
			string role
			bool is_active
		}
		PROJECT {
			int project_id PK
			int tenant_id FK
			string project_key
			string title
			string owner
		}
		EPIC {
			int epic_id PK
			int project_id FK
			string title
			string status
		}
		STORY {
			int story_id PK
			int epic_id FK
			string title
			int points
			string status
		}
		TASK {
			int task_id PK
			int story_id FK
			int assignee_user_id FK
			int sprint_id FK
			string title
			string priority
			string status
			datetime created_utc
			datetime due_utc
		}
		TASK_COMMENT {
			int comment_id PK
			int task_id FK
			int author_user_id FK
			string body
			datetime created_utc
		}
		TASK_ATTACHMENT {
			int attachment_id PK
			int task_id FK
			string file_name
			string uri
			int size_kb
		}
		TAG {
			int tag_id PK
			string tag_name
			string color_hex
		}
		TASK_TAG {
			int task_id FK
			int tag_id FK
		}
		SPRINT {
			int sprint_id PK
			int project_id FK
			string sprint_name
			date start_date
			date end_date
		}
		RELEASE {
			int release_id PK
			int project_id FK
			string version
			datetime release_utc
			string channel
		}
		CHANGE_LOG {
			int change_id PK
			int release_id FK
			string area
			string note
		}
		ENVIRONMENT {
			int environment_id PK
			string env_name
			string region
			string tier
		}
		SERVICE {
			int service_id PK
			string service_name
			string owner_team
			string repo
		}
		DEPLOYMENT {
			int deployment_id PK
			int release_id FK
			int environment_id FK
			int service_id FK
			datetime deployed_utc
			string result
		}
		INCIDENT {
			int incident_id PK
			int service_id FK
			int oncall_user_id FK
			string severity
			string title
			datetime opened_utc
			datetime closed_utc
		}
		INCIDENT_EVENT {
			int event_id PK
			int incident_id FK
			datetime event_utc
			string event_type
			string details
		}
		RCA_ITEM {
			int rca_id PK
			int incident_id FK
			string category
			string action_item
			string owner
		}
		API_CLIENT {
			int client_id PK
			int project_id FK
			string client_name
			string auth_type
		}
		API_TOKEN {
			int token_id PK
			int client_id FK
			datetime issued_utc
			datetime expires_utc
			bool revoked
		}
		AUDIT_LOG {
			int audit_id PK
			int tenant_id FK
			int actor_user_id FK
			datetime event_utc
			string action
			string object_type
			string object_id
		}
"@
		}
		[pscustomobject]@{
			Name = 'Gantt Plan'
			Description = 'Mermaid Gantt sample for a project timeline.'
			Format = 'Mermaid'
			Source = @"
gantt
		title Release Plan
		dateFormat  YYYY-MM-DD
		section Build
		Requirements      :a1, 2026-08-01, 5d
		Development       :a2, after a1, 10d
		section Test
		Integration Test  :b1, after a2, 5d
		UAT               :b2, after b1, 4d
		section Deploy
		Go Live           :milestone, c1, after b2, 0d
"@
		}
		[pscustomobject]@{
			Name = 'Sequence - API Call'
			Description = 'Mermaid sequence diagram with request flow.'
			Format = 'Mermaid'
			Source = @"
sequenceDiagram
		participant UI
		participant API
		participant DB
		UI->>API: GET /orders
		API->>DB: Query recent orders
		DB-->>API: Rows
		API-->>UI: 200 + JSON
"@
		}
	)
}

function Set-FormatSelection {
	param([string]$Format)
	switch ($Format) {
		'Mermaid' { $controls['FormatCombo'].SelectedIndex = 0 }
		'SVG' { $controls['FormatCombo'].SelectedIndex = 1 }
		'HTML' { $controls['FormatCombo'].SelectedIndex = 2 }
	}
}

function Load-SampleFromGridSelection {
	$selected = $controls['SampleGrid'].SelectedItem
	if (-not $selected) { return }

	Set-FormatSelection -Format ([string]$selected.Format)
	$controls['SourceEditor'].Text = [string]$selected.Source
	$script:currentFilePath = ''
	Set-StatusText -Message ("Loaded sample: {0}" -f [string]$selected.Name)
	Render-Preview
}

function Initialize-SampleGrid {
	$script:sampleItems.Clear()
	foreach ($s in Get-SampleLibrary) {
		$script:sampleItems.Add($s)
	}
	$controls['SampleGrid'].ItemsSource = $script:sampleItems
}

function Convert-ToDeflateBase64Url {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text
	)

	$bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
	$memory = New-Object System.IO.MemoryStream
	try {
		$deflate = New-Object System.IO.Compression.DeflateStream($memory, [System.IO.Compression.CompressionMode]::Compress)
		try {
			$deflate.Write($bytes, 0, $bytes.Length)
		}
		finally {
			$deflate.Dispose()
		}

		$compressed = $memory.ToArray()
		$base64 = [Convert]::ToBase64String($compressed)
		$base64.TrimEnd('=').Replace('+', '-').Replace('/', '_')
	}
	finally {
		$memory.Dispose()
	}
}

function Convert-MermaidSourceToSvgViaKroki {
	param(
		[Parameter(Mandatory = $true)]
		[string]$MermaidSource
	)

	$url = "$($script:krokiBaseUrl)/mermaid/svg"

	# Use system proxy and Windows default credentials to support corporate proxy auth.
	$proxy = [System.Net.WebRequest]::GetSystemWebProxy()
	if ($proxy) {
		$proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
	}

	$invokeParams = @{
		Uri = $url
		Method = 'Post'
		Body = $MermaidSource
		ContentType = 'text/plain; charset=utf-8'
		UseBasicParsing = $true
		TimeoutSec = 20
		ProxyUseDefaultCredentials = $true
	}

	if ($proxy) {
		$proxyUri = $proxy.GetProxy([Uri]$url)
		if ($proxyUri -and $proxyUri.AbsoluteUri -ne $url) {
			$invokeParams['Proxy'] = $proxyUri.AbsoluteUri
		}
	}

	try {
		$resp = Invoke-WebRequest @invokeParams
	}
	catch {
		if ($_.Exception.Response) {
			$response = $_.Exception.Response
			$reader = $null
			try {
				$stream = $response.GetResponseStream()
				if ($stream) {
					$reader = New-Object System.IO.StreamReader($stream)
					$body = $reader.ReadToEnd()
					if ($body) {
						throw "Kroki request failed: $($_.Exception.Message) Response: $body"
					}
				}
			}
			finally {
				if ($reader) { $reader.Dispose() }
			}
		}

		throw
	}
	if ($resp.StatusCode -lt 200 -or $resp.StatusCode -ge 300) {
		throw "Kroki render failed with status code $($resp.StatusCode)."
	}

	if (-not $resp.Content -or $resp.Content -notmatch '<svg') {
		throw 'Kroki did not return SVG content.'
	}

	$resp.Content
}

function Convert-MermaidSourceToPreviewHtml {
	param(
		[Parameter(Mandatory = $true)]
		[string]$MermaidSource
	)

	try {
		$svg = Convert-MermaidSourceToSvgViaKroki -MermaidSource $MermaidSource
		return @"
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta charset="utf-8" />
  <style>
	body { font-family: Segoe UI, Arial, sans-serif; margin: 0; padding: 12px; background: #0B1220; color: #E2E8F0; }
	.hint { color: #93C5FD; margin-bottom: 10px; font-size: 13px; }
	.panel { background: #111827; border: 1px solid #334155; border-radius: 10px; padding: 12px; overflow: auto; }
	.zoomWrap { transform: scale($($script:previewZoom.ToString([System.Globalization.CultureInfo]::InvariantCulture))); transform-origin: top left; width: fit-content; }
	svg { height: auto; }
  </style>
</head>
<body>
  <div class="hint">Mermaid rendered via Kroki SVG service.</div>
  <div class="panel">
		<div class="zoomWrap">
$svg
		</div>
  </div>
</body>
</html>
"@
	}
	catch {
		$safeMermaid = [System.Web.HttpUtility]::HtmlEncode($MermaidSource)
		$err = [System.Web.HttpUtility]::HtmlEncode($_.Exception.Message)
		$baseUrlEncoded = [System.Web.HttpUtility]::HtmlEncode($script:krokiBaseUrl)
		return @"
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta charset="utf-8" />
  <style>
	body { font-family: Segoe UI, Arial, sans-serif; margin: 0; padding: 12px; background: #0B1220; color: #E2E8F0; }
	.mermaid { background: #111827; border: 1px solid #334155; border-radius: 10px; padding: 12px; }
	.hint { color: #FDE68A; margin-bottom: 10px; font-size: 13px; }
	.zoomWrap { transform: scale($($script:previewZoom.ToString([System.Globalization.CultureInfo]::InvariantCulture))); transform-origin: top left; width: fit-content; }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
  <script>
	try {
	  mermaid.initialize({ startOnLoad: true, theme: 'dark' });
	} catch (e) {
	  console.log('Mermaid init error: ' + e);
	}
  </script>
</head>
<body>
	<div class="hint">Kroki SVG render unavailable ($err). Using browser Mermaid JS fallback.</div>
	<div class="hint">Kroki endpoint: $baseUrlEncoded (set KROKI_BASE_URL to override).</div>
	<div class="zoomWrap">
	<svg xmlns="http://www.w3.org/2000/svg" width="760" height="120" viewBox="0 0 760 120">
	  <rect x="0" y="0" width="760" height="120" fill="#111827" stroke="#334155"/>
	  <text x="24" y="48" fill="#93C5FD" font-size="26" font-family="Segoe UI">Mermaid Fallback Test Banner</text>
	  <text x="24" y="82" fill="#FDE68A" font-size="16" font-family="Segoe UI">If this banner appears, preview rendering is working but Kroki/JS Mermaid failed.</text>
	</svg>
	<div class="mermaid">$safeMermaid</div>
	</div>
</body>
</html>
"@
	}
}

function Convert-SourceToPreviewHtml {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Format,
		[Parameter(Mandatory = $true)]
		[string]$Source
	)

	switch ($Format) {
		'Mermaid' {
			Convert-MermaidSourceToPreviewHtml -MermaidSource $Source
		}
		'SVG' {
			# Basic validation to produce friendly diagnostics before preview.
			[void][xml]$Source
@"
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta charset="utf-8" />
  <style>
	body { margin: 0; padding: 12px; background: #0B1220; }
	.panel { overflow: auto; }
	.zoomWrap { transform: scale($($script:previewZoom.ToString([System.Globalization.CultureInfo]::InvariantCulture))); transform-origin: top left; width: fit-content; }
  </style>
</head>
<body>
	<div class="panel">
		<div class="zoomWrap">
$Source
		</div>
	</div>
</body>
</html>
"@
		}
		'HTML' {
			$Source
		}
		default {
			throw "Unsupported format: $Format"
		}
	}
}

function Render-Preview {
	$format = Get-SelectedFormat
	$source = [string]$controls['SourceEditor'].Text

	try {
		$html = Convert-SourceToPreviewHtml -Format $format -Source $source
		$controls['PreviewBrowser'].NavigateToString($html)
		$script:lastPreviewHtml = $html
		Set-ErrorText -Message ''
		$controls['RenderInfoText'].Text = "Format: $format"
		Set-StatusText -Message ("Rendered: {0}" -f (Get-Date).ToString('HH:mm:ss'))
	}
	catch {
		Set-ErrorText -Message $_.Exception.Message
		Set-StatusText -Message 'Render failed'
	}
}

function Set-PreviewZoom {
	param(
		[Parameter(Mandatory = $true)]
		[double]$NewZoom
	)

	$script:previewZoom = [Math]::Max(0.50, [Math]::Min(2.50, $NewZoom))
	Set-StatusText -Message ("Preview zoom: {0}%" -f [int]([Math]::Round($script:previewZoom * 100)))
	Render-Preview
}

function New-DocumentFromFormat {
	$format = Get-SelectedFormat
	$controls['SourceEditor'].Text = Get-SampleSource -Format $format
	$script:currentFilePath = ''
	Set-StatusText -Message "New $format document"
	Render-Preview
}

function Run-SelfTestRender {
	$format = Get-SelectedFormat
	$controls['SourceEditor'].Text = Get-SampleSource -Format $format
	Set-StatusText -Message "Self test render: $format"
	Render-Preview
}

function Open-SourceFile {
	$dialog = New-Object Microsoft.Win32.OpenFileDialog
	$dialog.Filter = 'All Supported|*.mmd;*.mermaid;*.svg;*.html;*.htm;*.txt|Mermaid|*.mmd;*.mermaid|SVG|*.svg|HTML|*.html;*.htm|Text|*.txt|All Files|*.*'

	if (-not $dialog.ShowDialog()) { return }

	$path = $dialog.FileName
	$ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
	$text = Get-Content -LiteralPath $path -Raw
	$controls['SourceEditor'].Text = $text
	$script:currentFilePath = $path

	switch ($ext) {
		'.mmd' { $controls['FormatCombo'].SelectedIndex = 0 }
		'.mermaid' { $controls['FormatCombo'].SelectedIndex = 0 }
		'.svg' { $controls['FormatCombo'].SelectedIndex = 1 }
		'.html' { $controls['FormatCombo'].SelectedIndex = 2 }
		'.htm' { $controls['FormatCombo'].SelectedIndex = 2 }
	}

	Set-StatusText -Message "Opened: $path"
	Render-Preview
}

function Save-SourceFile {
	$format = Get-SelectedFormat
	$defaultExt = Get-DefaultExtensionForFormat -Format $format
	$targetPath = $script:currentFilePath

	if (-not $targetPath) {
		$dialog = New-Object Microsoft.Win32.SaveFileDialog
		$dialog.Filter = 'Mermaid|*.mmd|SVG|*.svg|HTML|*.html|Text|*.txt|All Files|*.*'
		$dialog.DefaultExt = $defaultExt
		$dialog.FileName = "diagram$defaultExt"
		if (-not $dialog.ShowDialog()) { return }
		$targetPath = $dialog.FileName
	}

	Set-Content -LiteralPath $targetPath -Value ([string]$controls['SourceEditor'].Text) -Encoding UTF8
	$script:currentFilePath = $targetPath
	Set-StatusText -Message "Saved: $targetPath"
}

function Export-PreviewHtml {
	if (-not $script:lastPreviewHtml) {
		Render-Preview
	}

	if (-not $script:lastPreviewHtml) {
		Set-StatusText -Message 'Nothing to export'
		return
	}

	$dialog = New-Object Microsoft.Win32.SaveFileDialog
	$dialog.Filter = 'HTML|*.html'
	$dialog.DefaultExt = '.html'
	$dialog.FileName = 'preview.html'

	if (-not $dialog.ShowDialog()) { return }

	$path = $dialog.FileName
	Set-Content -LiteralPath $path -Value $script:lastPreviewHtml -Encoding UTF8
	Set-StatusText -Message "Preview HTML exported: $path"
}

$script:autoRenderTimer = New-Object Windows.Threading.DispatcherTimer
$script:autoRenderTimer.Interval = [TimeSpan]::FromMilliseconds($script:autoRenderDelayMs)
$script:autoRenderTimer.Add_Tick({
	$script:autoRenderTimer.Stop()
	if ($controls['AutoRenderCheck'].IsChecked) {
		Render-Preview
	}
})

$controls['SourceEditor'].Add_TextChanged({
	if ($controls['AutoRenderCheck'].IsChecked) {
		$script:autoRenderTimer.Stop()
		$script:autoRenderTimer.Start()
	}
})

$controls['FormatCombo'].Add_SelectionChanged({
	$controls['RenderInfoText'].Text = "Format: $(Get-SelectedFormat)"
	if ($controls['AutoRenderCheck'].IsChecked) {
		Render-Preview
	}
})

$controls['NewButton'].Add_Click({ New-DocumentFromFormat })
$controls['OpenButton'].Add_Click({ Open-SourceFile })
$controls['SaveButton'].Add_Click({ Save-SourceFile })
$controls['RenderButton'].Add_Click({ Render-Preview })
$controls['ExportHtmlButton'].Add_Click({ Export-PreviewHtml })
$controls['TestButton'].Add_Click({ Run-SelfTestRender })
$controls['PreviewZoomInButton'].Add_Click({ Set-PreviewZoom -NewZoom ($script:previewZoom + 0.10) })
$controls['PreviewZoomOutButton'].Add_Click({ Set-PreviewZoom -NewZoom ($script:previewZoom - 0.10) })
$controls['SampleGrid'].Add_SelectionChanged({ Load-SampleFromGridSelection })

$window.Add_Closing({
	if ($script:autoRenderTimer) {
		$script:autoRenderTimer.Stop()
	}
})

Initialize-SampleGrid
New-DocumentFromFormat
[void]$window.ShowDialog()
