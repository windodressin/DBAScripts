/* Get No of Processors,Speed and its usage*/
Function Get-CPUs {
 param ($server)
$processors = get-wmiobject -computername $server win32_processor
$cpuSpeed = ((get-wmiobject -computername $server Win32_Processor).MaxClockSpeed)/1000
$cores=0
if (@($processors)[0].NumberOfCores)
    {
        $cores = @($processors).count * @($processors)[0].NumberOfCores
    }
    else
    {
        $cores = @($processors).count
    }
$sockets = @(@($processors) | % {$_.SocketDesignation} |select-object -unique).count;
$Usage=(get-counter -ComputerName $Server -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 2 -MaxSamples 10 | select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average
return "Cores: $cores, Sockets: $sockets Speed: $cpuSpeed CPUUsage% : $Usage";
}
-MaxSamples Int
  The number of samples to get from each counter.
  The default is 1 sample. To get samples continuously (no max sample size), use -Continuous.
 -SampleInterval int
  The time between samples in seconds.
  The minimum value and the default value are 1 second.
Get the current "% Processor Time" combined values for all processors on the local computer. Collect data every 2 seconds until 10 sample values are collected. The output will take 20 seconds to give you a result. You can change the sample and MaxSample parameter.
 
