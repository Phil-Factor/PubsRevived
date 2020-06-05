$TheGithubDirectory ='S:\work\Github\PubsRevived'
cd $TheGithubDirectory
 & '.\Posh\SourceControl.ps1'

<#  do the initial save into source control #>
SourceControl @{
	'source' = @{ #give the detail;s of the source
		'Server' = 'MyServer'; 'Database' = 'Pubs'; 'uid' = 'PhilFactor';
		'version' = '1.1.1'
	}; #The version of the database in the database 
	'Directory' = $TheGithubDirectory #where the version-control directory is
}

<#  now make sure you've done the first alterations in the handcut migration script 
 into Pubsdev before running this #>

SourceControl @{
	'source' = @{ #give the detail;s of the source
		'Server' = 'MyServer'; 'Database' = 'PubsDev'; 'uid' = 'PhilFactor';
		'version' = '1.1.2'
	}; #The version of the database in the database 
	'Directory' = $TheGithubDirectory #where the version-control directory is
}

<# before tyou run the next one, run the  handcut migration script #>

SourceControl @{
	'source' = @{ #give the detail;s of the source
		'Server' = 'MyServer'; 'Database' = 'PubsDev'; 'uid' = 'PhilFactor';
		'version' = '1.2.1'
	}; #The version of the database in the database 
	'Directory' = $TheGithubDirectory #where the version-control directory is
}

<#  now you can run this migration script #>

SourceControl @{
	'target' = @{
		'Server' = 'MyServer'; 'Database' = 'Pubs'; 'uid' = 'PhilFactor';
		'version' = '1.1.1'
	}; #The version of the database in the database 
	'Directory' = $TheGithubDirectory #where the version-control directory is
}
