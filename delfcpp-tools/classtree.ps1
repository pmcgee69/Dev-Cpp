param([int] $ProcessId)
# Selects the Classes tab of Dev-C++'s left panel and lists the class browser's tree items, by UI Automation.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$A = [System.Windows.Automation.AutomationElement]
$root = $A::RootElement.FindFirst('Children', (New-Object System.Windows.Automation.PropertyCondition($A::ProcessIdProperty, $ProcessId)))
$tab = $root.FindFirst('Descendants', (New-Object System.Windows.Automation.AndCondition(
  (New-Object System.Windows.Automation.PropertyCondition($A::ControlTypeProperty, [System.Windows.Automation.ControlType]::TabItem)),
  (New-Object System.Windows.Automation.PropertyCondition($A::NameProperty, 'Classes')))))
if (-not $tab) { 'no Classes tab found'; exit 1 }
$tab.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
Start-Sleep -Seconds 2
$trees = $root.FindAll('Descendants', (New-Object System.Windows.Automation.PropertyCondition($A::ControlTypeProperty, [System.Windows.Automation.ControlType]::Tree)))
foreach ($t in $trees) {
  "tree: '$($t.Current.Name)' ($($t.Current.ClassName))"
  # expand everything, then list
  $items = $t.FindAll('Descendants', (New-Object System.Windows.Automation.PropertyCondition($A::ControlTypeProperty, [System.Windows.Automation.ControlType]::TreeItem)))
  foreach ($i in $items) { try { $i.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern).Expand() } catch {} }
  Start-Sleep -Milliseconds 500
  $items = $t.FindAll('Descendants', (New-Object System.Windows.Automation.PropertyCondition($A::ControlTypeProperty, [System.Windows.Automation.ControlType]::TreeItem)))
  foreach ($i in $items) { "   " + $i.Current.Name }
}
