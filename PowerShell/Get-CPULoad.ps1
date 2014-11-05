Get-WmiObject -computer server -class win32_processor | Measure-Object -property LoadPercentage -Average | FL average
