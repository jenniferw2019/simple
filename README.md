# Simple-C Compiler

The purpose of this lab is to write a compiler for the Simple-C language. Our compiler will generate x86-64 assembly language that can be assembled to produce an executable file.

The Simple-C language is a subset of the C language that only has following types:  
* long, long\*, char\* char\*\*, and void  

It also supports arithmetic operators, logical operators, equality operators, relational operators and flow control if, if/else, while, for, do while.

The Simple-C Compiler uses Lex and Yacc, the UNIX standard tools, to generate the Scanner and Parser. The Scanner first puts together the characters in a program into “tokens” that represent language keywords such as “if”, left parenthesis, right parenthesis, etc. Then the Parser uses grammar rules to describe the program’s syntax. The parser file also contains “actions” to write the assembly instruction in a file used to generate the executable.

Since the code generation is intended to be done in a simple pass, it will be easier to generate code that simulates a stack machine. However, instead of using memory all the time for the stack, we will be using some of the registers for optimization purposes. In this way, registers and not memory will be used in most of the cases. These registers will be saved when entering a function and restored before leaving a function. When more than 5 entries in the stack are needed then the stack can be extended to the execution stack.

The compiler implements three types of variables: global, local, and arguments. Global variables are stored in the program’s DATA segment, local variables are stored in the Execution Stack and can be referenced using the frame pointer register rbp. arguments can be handled as local variables that take the value of the arguments as the initial value.

By completing this project, I  experience how high-level languages are translated to machine code and how it runs in the underlying hardware.
