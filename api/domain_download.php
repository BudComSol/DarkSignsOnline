<?

require("config.php");


$u=trim($u);
$p=trim($p);
$returnwith=trim($returnwith);
$d=str_replace("http://","",str_replace("www.","",trim($d)));



if (trim($returnwith)==""){$returnwith="2000";}
echo $returnwith;




$port=trim($port);
if ($port < 1 || $port > 65536){die("Error: Port number must be between 1 and 65536.<end>"); }





if (auth()=="1001"){
	
	//----------------------------------------------------------------------------------------------------------
	//NOTE - when modifying this script, consider that you may need to modify domain_download.php as well!!!
	//----------------------------------------------------------------------------------------------------------
	
	$originaldomain=trim($d);
	$d=getdomain($d); //make sure its a domain name so mysql can identify it


	mysql_connect("localhost", $mysql_username, $mysql_password); mysql_select_db($mysql_database);
	$result=mysql_query("SELECT ind from domains where domain='$d' and owner='$u'")or die(mysql_error());  
	
	if (strtolower($u)=="admin"){}else{
		//only ADMIN can download from anyone's domain name!
		if (mysql_num_rows($result)==1){}else{
		
			//check subowners
			$result2=mysql_query("SELECT subowners from domains where domain='$d'");
				while($row = mysql_fetch_array( $result2 )) {
					$subowners = strtolower($row['subowners']);
				}
				
			if(strstr($subowners,":".trim(strtolower($u)).":")){
				//subowner found, continue!
			}else{		
				die("Error: $d [user denied]newlineMake sure this domain name is registered to you.<end>");
			}
			
			
		}
	}
	
	//----------------------------------------------------------------------------------------------------------
	//NOTE - when modifying this script, consider that you may need to modify domain_download.php as well!!!
	//----------------------------------------------------------------------------------------------------------
	

	//is it a domain?
	if (domain_exists($d)){
		
		$result=mysql_query("SELECT script from domain_scripts where domain='$d' and port='$port'");
	
		if (mysql_num_rows($result)>0){
			//grab the file to download!
			while($row = mysql_fetch_array( $result )) {		$script = $row['script'];			}

			$script=str_replace("\n","*- -*",$script);
			$script=str_replace("\r","",$script);
			die("$filename:$script<end>");			
			
		}else{
			//add it as new
		
			die("No Script Found: ".strtoupper($originaldomain).":$port<end>");
			
		}

			
			
	
	}else{
	
		//domain not found
		die("Server Not Found: ".strtoupper($originaldomain)."<end>");
	}

}else{

	echo "Access Denied 65233";
}


echo "<end>";




?>