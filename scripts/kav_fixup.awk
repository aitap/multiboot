($1 == "menuentry") {
	print "if [ ${grub_platform} = " platform " ]; then\n" \
		$0 "\nloopback loop /rescue/rescue.iso"
}
($1 == "linux") { for (i=2;i<=NF;i++) if ($i ~ /^root=live:/) $i="root=live:/dev/wtf" }
($1 == "}") { $0 = $0 "\nfi" }
($1 ~ /linux|initrd/) {$2 = "(loop)" $2}
($1 ~ /linux|initrd|}/){print}
