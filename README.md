# Microsoft GW-BASIC Interpreter Source Code

This repo contains the original source-code for Microsoft's GW-BASIC interpreter, as of 1983,
adjusted for assembling with available versions of the Microsoft Macro Assembler.

## Announcement blog
https://devblogs.microsoft.com/commandline/microsoft-open-sources-gw-basic/

## Progress

### Assembling

All files can now be assembled with Microsoft MASM 5.1A.
This is the version that currently seems to match the code most closely.

### Implementation

The interpreter is semi-working, but large parts of the platform-specific
support code are still missing or incomplete.

Specifically, [dspinellis](https://github.com/dspinellis/GW-BASIC) observed
that the following functions were missing from the original source code
release, and have to be added:
`CLREOL`,
`CLRSCN`,
`CSRATR`,
`CSRDSP`,
`DONOTE`,
`DOWNC`,
`EDTMAP`,
`FETCHC`,
`FKYADV`,
`FKYFMT`,
`GETFBC`,
`GETHED`,
`GRPSIZ`,
`GTASPC`,
`GWINI`,
`GWTERM`,
`INFMAP`,
`INICOM`,
`INKMAP`,
`KEYINP`,
`LCPY`,
`LEFTC`,
`MAPSUP`,
`MAPXYC`,
`NREAD`,
`NSETCX`,
`NWRITE`,
`PEKFLT`,
`PGINIT`,
`PIXSIZ`,
`PNTINI`,
`POKFLT`,
`POLLEV`,
`PRTMAP`,
`RDPEN`,
`RDSTIK`,
`RDTRIG`,
`READC`,
`RECCOM`,
`RIGHTC`,
`SCALXY`,
`SCANL`,
`SCANR`,
`SCRATR`,
`SCRINP`,
`SCROLL`,
`SCROUT`,
`SCRSTT`,
`SEGINI`,
`SETATR`,
`SETC`,
`SETCBF`,
`SETCLR`,
`SETFBC`,
`SNDCOM`,
`SNDLPT`,
`STACOM`,
`STOREC`,
`SWIDTH`,
`TDOWNC`,
`TRMCOM`,
`TUPC`,
`UPC`.

Some of these have been implemented in the new module `OEM.ASM`.

Many, but not all, of the needed routines, such as `SETC` and `MAPXYC`,
 turn out to be present in
`BASICA.COM` from [Microsoft's earlier MS-DOS v1.25 code
release](https://github.com/microsoft/MS-DOS).  However, `BASICA.COM` is
only released in binary form, so some analysis is needed to extract the
routines.

## Building instructions
Using  [DOSBox](https://www.dosbox.com/) mount a directory containing:
* This code
* The Microsoft Macro Assembler (MASM) version 5.1A (`masm.exe`).
* The Microsoft MAKE and LINK programs that come with MASM (`make.exe`, `link.exe`).

Run `make makefile` to assemble the files.
Note the tools may leave behind  party-built executables or object files.
If you want to rebuild them without changing the source code, you need
to delete these files by hand.

You can fetch MASM 5.1A from
[this site](https://www.pcjs.org/software/pcx86/lang/microsoft/masm/5.10x/) as follows.
* From the pull-down menu select `MS MAcro Assembler 5.10A (Update)`
* Press the `Load` button to load the disk image into the emulator
* Press the `Save` button to save the disk image to your computer
* Copy  the saved disk image to a Linux computer
* Mount the image using the command `sudo mount MASM51A-UPDATE.img /mnt`
* Copy the files from `/mnt` to your development directory

## License

All files within this repo are released under the [MIT (OSI) License]( https://en.wikipedia.org/wiki/MIT_License) as per the [LICENSE file](https://github.com/Microsoft/GW-BASIC/blob/master/LICENSE) stored in the root of this repo.

## Contributing

Pull requests addressing problems in getting GW-BASIC to build and run
are welcomed.

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).  For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
