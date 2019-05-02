($1 == "menuentry") {
	$0 = $0 "\nloopback loop " path
	if (uuid) {
		$0 = $0 "\n probe -u $root --set=rootuuid"
	}
}
($1 ~ /linux|initrd/) {$2 = "(loop)" $2}
($1 == "linux") { $0 = $0 " " addparams }
($1 != "source") {print}
