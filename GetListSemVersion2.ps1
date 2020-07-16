Clear-Host


Param (
    [Parameter(HelpMessage="GitFolder", Mandatory=$true)]$GitFolder,
    [Parameter(HelpMessage="OutputTemplate")]$OutputTemplate
)


Write-Host $GitFolder

if(($GitFolder -ne $null) -and ($Template -ne ""))
{
    return $null
}
else
{
    $GitFolder = "-- $GitFolder"
}


function setVersionMerges($FullCommits, $MergeCommits)
{
    $major = 1
    $minor = 0
    $patch = 0

    foreach($merge in $MergeCommits)
    {        
        $str = "SemVer $major.$minor.$patch "
        $merge.Comment += $str
        $minor++
    }

    return $MergeCommits
}

function getStrWithSemVer($strComment)
{
    if($strComment -like '*SemVer*')
    {
        $Matches = $null

        if(($strComment -match '(?<=SemVer)\s(.+\b)') -eq $true)
        {
            if(($Matches -ne $null) -and ($Matches.Count -ne 0)) 
            {
                return ($Matches[0] -replace '\s','')
            }
        } 
    }
    else
    { 
        return "";
    }
}

function toSemVer($version, $strCommitId)
{
    $version -match "^(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?(\-(?<pre>[0-9A-Za-z\-\.]+))?(\+(?<build>[0-9A-Za-z\-\.]+))?$" | Out-Null
    $major = [int]$matches['major']
    $minor = [int]$matches['minor']
    $patch = [int]$matches['patch']
    
    if($matches['pre'] -eq $null)
    {
        $pre = @()
    }
    else
    {
        $pre = $matches['pre'].Split(".")
    }

    New-Object PSObject -Property @{ 
        
        Major = $major
        Minor = $minor
        Patch = $patch
        Pre = $pre
        VersionString = $version
        CommitId = $strCommitId
    }
}

function toStringVer($version)
{
    $strAll = @()

    foreach($ver in $version)
    {
        $commitId = $ver.CommitId
        $major = $ver.Major
        $minor = $ver.Minor
        $patch = $ver.Patch

        $str = "Commit: $commitId : $major.$minor.$patch "
        $strAll += $str
    }
    #
    return $strAll
}

function MAIN()
{
    #�������� ��� ������� �����������
    $gitFullHistory = (git log --pretty=format:"%ai`t%H`t%an`t%ae`t%s" --date=iso $GitFolder | sort) | 
        ConvertFrom-Csv -Delimiter "`t" -Header ("Date","CommitId","Author","Email","Comment")

    $gitFullHistory
    $gitMergesHistory = @()
    if(($gitFullHistory -ne $null) -and ($gitFullHistory.Count -ne 0))
    {
        $gitMergesHistory += $gitFullHistory[0]
    }
    else
    {
        return $null
    }

    #�������� ��� ������� ����������� � ��������� 
    #(!!! ���� ������ ������� � "�����������", ����� ��� ����� ����� ��������� �� ������ �������)
    $gitMergesHistoryBattary = (git log --merges $GitFolder --pretty=format:"%ai`t%H`t%an`t%ae`t%s" --date=iso | sort) | 
        ConvertFrom-Csv -Delimiter "`t" -Header ("Date","CommitId","Author","Email","Comment")

    foreach($g in $gitMergesHistoryBattary)
    {
        $gitMergesHistory += $g
    }


    $merges = @()
    
    #��� ����� (1.*.0) ������� �������
    $merges = setVersionMerges $gitFullHistory $gitMergesHistory

    foreach($merge in $merges) 
    {
        #�����������
        $merge.Comment = getStrWithSemVer $merge.Comment
    }
    
    $versions = @()

    foreach($i in $merges) 
    {    
        if(($i.Comment -ne $null) -and ($i.Comment -ne ""))
        {
            #��������� � ������ ��������
            $versions += toSemVer $i.Comment $i.CommitId
        }
    }

    # ��������� ������ ������ ��� ��������� �������� �������
    $lastObject = 0
    for($i = 0; $i -lt $versions.Count; $i++)
    {
        $countPatch = 0
        $count = 0
        foreach($commit in $gitFullHistory)
        {
            if($commit.CommitId -eq $versions[$i+1].CommitId )
            {
                $lastObject = $count
                break
            }
            else
            {
                if($count -gt $lastObject)
                {
                    $countPatch++   
                }             
            }
            $count++
        }
        $versions[$i].Patch = $countPatch
    }

    # ������� ��������� � ������� "Commit: <��� �������> : <������ ������� �������>"
    $strAll = toStringVer $versions
    foreach($str in $strAll)
    {
        Write-Host $str
    }

}

MAIN