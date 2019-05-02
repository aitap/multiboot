($1 == "menuentry") {
	$0 = $0 "\nloopback loop " path
	if (uuid) {
		$0 = $0 "\nprobe -u $root --set=rootuuid"
	}
}
($1 == "linux") {
	$2 = "(loop)" $2
	$0 = $0 " " addparams
}
($1 == "initrd") {
	for (i = 2; i <= NF; i++) {
		$i = "(loop)" $i
	}
}
($1 != "source") {print}
