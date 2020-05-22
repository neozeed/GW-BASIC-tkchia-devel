# Microsoft GW-BASIC Interpreter Source Code

This repo contains the original source-code for Microsoft's GW-BASIC interpreter, as of 1983.

## Announcement blog
https://devblogs.microsoft.com/commandline/microsoft-open-sources-gw-basic/

## Information

Here I'm working to compile the original code with Microsoft MASM 5.1A.
This is the version that currently seems to match the code most closely.

Currently 33 of the 36 files have been compiled.
Pull requests for fixing the remaining compilation programs are welcomed.

## Building instructions
Under [DOSBox](https://www.dosbox.com/) mount a directory containing:
* this code
* MASM 5.1A
* The Microsoft make program that comes with MASM.

Run `make makefile` to assemble the files.

You can fetch MASM 5.1A from
[this site](https://www.pcjs.org/software/pcx86/lang/microsoft/masm/4.00/).
From the pull-down menu load and then save the corresponding disk.
Mount the image on a Linux computer and copy the files across to
your development directory.

## License

All files within this repo are released under the [MIT (OSI) License]( https://en.wikipedia.org/wiki/MIT_License) as per the [LICENSE file](https://github.com/Microsoft/GW-BASIC/blob/master/LICENSE) stored in the root of this repo.

## Contributing

Pull requests addressing problems in getting GW-BASIC to build and run
are welcomed.

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).  For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
