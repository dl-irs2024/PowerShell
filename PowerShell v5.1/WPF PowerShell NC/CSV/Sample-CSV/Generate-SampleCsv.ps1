$ErrorActionPreference = "Stop"
$root = Join-Path (Split-Path -Parent $PSScriptRoot) 'Sample-CSV'
New-Item -ItemType Directory -Path $root -Force | Out-Null

$rand = [System.Random]::new()
function Pick([object[]]$arr) { $arr[$rand.Next(0,$arr.Count)] }
function New-CsvFile { param([string]$Path,[int]$Rows,[scriptblock]$Generator)
    $data = for($i=1; $i -le $Rows; $i++){ & $Generator $i }
    $data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

$firstNames=@('Ava','Liam','Noah','Emma','Olivia','Mason','Sophia','Elijah')
$lastNames=@('Smith','Johnson','Williams','Brown','Jones','Miller','Davis','Garcia')
$cities=@('Phoenix','Chicago','Dallas','Atlanta','Seattle','Denver','Boston','Miami')
$states=@('AZ','IL','TX','GA','WA','CO','MA','FL')
$streets=@('Maple St','Oak Ave','Pine Rd','Cedar Ln','Elm St','River Dr')
$products=@('Laptop Stand','Wireless Mouse','USB-C Hub','4K Monitor','Webcam Pro','Portable SSD')
$categories=@('Hardware','Accessories','Office','Audio','Storage')
$warehouses=@('WH-NY','WH-TX','WH-CA','WH-IL')
$clients=@('Acme Corp','Northwind LLC','Contoso Ltd','Fabrikam Inc','BlueYonder Co')
$consultants=@('J. Carter','A. Singh','M. Rivera','D. Kim','S. Patel')
$tasks=@('Data Cleanup','API Integration','UI Prototype','QA Regression','Report Build')
$countries=@('United States','Canada','Mexico','Brazil','United Kingdom','Germany','India','Japan')
$regions=@('North America','South America','Europe','Asia-Pacific')

New-CsvFile -Path (Join-Path $root 'addresses_contacts.csv') -Rows 48 -Generator {
 param($i); $fn=Pick $firstNames; $ln=Pick $lastNames; $n=$rand.Next(100,9999)
 [pscustomobject]@{ContactId=('C{0:0000}' -f $i);FirstName=$fn;LastName=$ln;Email=("{0}.{1}{2}@example.org" -f $fn.ToLower(),$ln.ToLower(),$rand.Next(1,99));Phone=('({0}) {1}-{2}' -f $rand.Next(200,999),$rand.Next(200,999),$rand.Next(1000,9999));Street=("$n $(Pick $streets)");City=(Pick $cities);State=(Pick $states);PostalCode=('{0:00000}' -f $rand.Next(10000,99999));LastUpdated=(Get-Date).AddDays(-$rand.Next(0,730)).ToString('yyyy-MM-dd')}
}

New-CsvFile -Path (Join-Path $root 'addresses_international.csv') -Rows 72 -Generator {
 param($i)
 [pscustomobject]@{RecordId=('INT-{0:0000}' -f $i);Organization=("Org-{0:000}" -f $rand.Next(1,350));Attention=("$(Pick $firstNames) $(Pick $lastNames)");AddressLine1=("$($rand.Next(1,9999)) $(Pick $streets)");AddressLine2=$(if($i%3 -eq 0){"Suite $($rand.Next(100,950))"}else{''});City=(Pick $cities);Region=(Pick $regions);Country=(Pick $countries);PostalCode=('{0:00000}' -f $rand.Next(10000,99999));IsPrimary=[bool]($i%4 -eq 0);CreatedDate=(Get-Date).AddDays(-$rand.Next(30,1200)).ToString('yyyy-MM-dd')}
}

New-CsvFile -Path (Join-Path $root 'product_inventory.csv') -Rows 125 -Generator {
 param($i); $cost=[math]::Round($rand.NextDouble()*180+10,2); $price=[math]::Round($cost*(1.2+$rand.NextDouble()*0.9),2)
 [pscustomobject]@{ProductId=('P-{0:00000}' -f $i);SKU=("SKU-$($rand.Next(100000,999999))");ProductName=(Pick $products);Category=(Pick $categories);Warehouse=(Pick $warehouses);QuantityOnHand=$rand.Next(0,900);ReorderPoint=$rand.Next(10,180);UnitCost=$cost;UnitPrice=$price;Supplier=("Supplier-$($rand.Next(1,65))");Status=(Pick @('InStock','BackOrder','Reserved','Discontinued','InTransit'));LastReceipt=(Get-Date).AddDays(-$rand.Next(0,180)).ToString('yyyy-MM-dd')}
}

New-CsvFile -Path (Join-Path $root 'product_shipments.csv') -Rows 96 -Generator {
 param($i); $ship=(Get-Date).AddDays(-$rand.Next(0,200))
 [pscustomobject]@{ShipmentId=('SHP-{0:00000}' -f $i);ProductId=('P-{0:00000}' -f $rand.Next(1,126));OrderNumber=("ORD-$($rand.Next(10000,99999))");WarehouseFrom=(Pick $warehouses);WarehouseTo=(Pick $warehouses);UnitsShipped=$rand.Next(1,220);Carrier=(Pick @('UPS','FedEx','USPS','DHL','Local Freight'));TrackingNumber=("TRK$($rand.Next(10000000,99999999))");ShipDate=$ship.ToString('yyyy-MM-dd');EstimatedArrival=$ship.AddDays($rand.Next(1,9)).ToString('yyyy-MM-dd');DeliveryStatus=(Pick @('Delivered','In Transit','Exception','Pending'))}
}

New-CsvFile -Path (Join-Path $root 'time_billing_entries.csv') -Rows 220 -Generator {
 param($i); $hrs=[math]::Round(($rand.NextDouble()*7.5)+0.5,2); $rate=$rand.Next(85,220)
 [pscustomobject]@{EntryId=('TB-{0:000000}' -f $i);EntryDate=(Get-Date).AddDays(-$rand.Next(0,120)).ToString('yyyy-MM-dd');Client=(Pick $clients);ProjectCode=("PRJ-$($rand.Next(100,999))");Consultant=(Pick $consultants);TaskCode=(Pick $tasks);Hours=$hrs;BillRate=$rate;Amount=[math]::Round($hrs*$rate,2);IsBillable=[bool]($rand.Next(0,10)-gt 1);BillingStatus=(Pick @('Draft','Submitted','Approved','Paid','Rejected'));Notes=("Work item $($rand.Next(1000,9999))")}
}

New-CsvFile -Path (Join-Path $root 'time_billing_summary.csv') -Rows 40 -Generator {
 param($i); $month=(Get-Date).AddMonths(-$rand.Next(0,12)).ToString('yyyy-MM'); $hours=[math]::Round($rand.NextDouble()*160+20,2); $avg=$rand.Next(90,190)
 [pscustomobject]@{SummaryId=('SUM-{0:0000}' -f $i);Month=$month;Client=(Pick $clients);Team=(Pick @('Team A','Team B','Team C','Team D'));TotalHours=$hours;AvgBillRate=$avg;TotalAmount=[math]::Round($hours*$avg,2);BillablePct=[math]::Round(($rand.NextDouble()*45)+50,2);OpenInvoices=$rand.Next(0,12)}
}

New-CsvFile -Path (Join-Path $root 'population_by_country.csv') -Rows 60 -Generator {
 param($i); $base=$rand.Next(500000,1450000000)
 [pscustomobject]@{Country=(Pick $countries);Region=(Pick $regions);CensusYear=$rand.Next(2005,2026);PopulationTotal=$base;UrbanPopulation=[int]($base*($rand.NextDouble()*0.5+0.35));RuralPopulation=[int]($base*($rand.NextDouble()*0.4+0.15));GrowthRatePct=[math]::Round(($rand.NextDouble()*4.5)-1.0,2);MedianAge=[math]::Round(($rand.NextDouble()*22)+20,1);DataSource=(Pick @('National Census','UN Estimate','World Bank','Regional Survey'))}
}

New-CsvFile -Path (Join-Path $root 'population_by_state_us.csv') -Rows 52 -Generator {
 param($i)
 $stateNames=@('Alabama','Alaska','Arizona','Arkansas','California','Colorado','Connecticut','Delaware','Florida','Georgia','Hawaii','Idaho','Illinois','Indiana','Iowa','Kansas','Kentucky','Louisiana','Maine','Maryland','Massachusetts','Michigan','Minnesota','Mississippi','Missouri','Montana','Nebraska','Nevada','New Hampshire','New Jersey','New Mexico','New York','North Carolina','North Dakota','Ohio','Oklahoma','Oregon','Pennsylvania','Rhode Island','South Carolina','South Dakota','Tennessee','Texas','Utah','Vermont','Virginia','Washington','West Virginia','Wisconsin','Wyoming','District of Columbia','Puerto Rico')
 $st=$stateNames[$i-1]
 [pscustomobject]@{StateOrTerritory=$st;CensusYear=2025;Population=$rand.Next(550000,39500000);Households=$rand.Next(200000,14500000);MedianIncome=$rand.Next(42000,98000);MedianAge=[math]::Round(($rand.NextDouble()*18)+29,1);AreaSqMi=$rand.Next(1000,270000);DensityPerSqMi=[math]::Round(($rand.NextDouble()*1200)+5,2);Growth5YearPct=[math]::Round(($rand.NextDouble()*14)-2,2)}
}

New-CsvFile -Path (Join-Path $root 'sales_orders.csv') -Rows 180 -Generator {
 param($i); $qty=$rand.Next(1,25); $price=[math]::Round($rand.NextDouble()*450+15,2)
 [pscustomobject]@{SalesOrderId=('SO-{0:000000}' -f $i);OrderDate=(Get-Date).AddDays(-$rand.Next(0,365)).ToString('yyyy-MM-dd');CustomerId=('CU-{0:00000}' -f $rand.Next(1,3000));ProductId=('P-{0:00000}' -f $rand.Next(1,126));Quantity=$qty;UnitPrice=$price;DiscountPct=[math]::Round($rand.NextDouble()*0.22,2);NetAmount=[math]::Round(($qty*$price)*(1-$rand.NextDouble()*0.18),2);SalesRep=(Pick @('Rep-01','Rep-02','Rep-03','Rep-04','Rep-05','Rep-06'));Region=(Pick @('West','Midwest','South','Northeast'));Fulfillment=(Pick @('Shipped','Pending','Partial','Cancelled'))}
}

Get-ChildItem -Path $root -Filter *.csv | Sort-Object Name | ForEach-Object {
 $rows = Import-Csv $_.FullName
 [pscustomobject]@{FileName=$_.Name;Rows=$rows.Count;Columns=$(if($rows.Count -gt 0){$rows[0].PSObject.Properties.Count}else{0})}
} | Format-Table -AutoSize
