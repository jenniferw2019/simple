%token  <string_val> WORD

%token  NOTOKEN LPARENT RPARENT LBRACE RBRACE LCURLY RCURLY COMA SEMICOLON EQUAL STRING_CONST LONG LONGSTAR VOID CHARSTAR CHARSTARSTAR INTEGER_CONST AMPERSAND OROR ANDAND EQUALEQUAL NOTEQUAL LESS GREAT LESSEQUAL GREATEQUAL PLUS MINUS TIMES DIVIDE PERCENT IF ELSE WHILE DO FOR CONTINUE BREAK RETURN SWITCH COLON CASE DEFAULT

%union  {
                char   *string_val;
                int nargs;
                int my_nlabel;
        }

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
  
int yylex();
int yyerror(const char * s);
 
extern int line_number;
const char * input_file;
char * asm_file;
FILE * fasm;
 
#define MAX_ARGS 5
int nargs;
char * args_table[MAX_ARGS];
 
#define MAX_GLOBALS 100
int nglobals = 0;
char * global_vars_table[MAX_GLOBALS];
int global_vars_type[MAX_GLOBALS];

#define MAX_LOCALS 32
int nlocals = 0;
char * local_vars_table[MAX_LOCALS];
int local_vars_type[MAX_LOCALS];

#define MAX_FUNCTIONS 100
int nfunctions = 0;
char * function_table[MAX_FUNCTIONS]; 
  
#define MAX_STRINGS 100
int nstrings = 0;
char * string_table[MAX_STRINGS];
 
char *regStk[]={ "rbx", "r10", "r13", "r14", "r15"};
char nregStk = sizeof(regStk)/sizeof(char*);

char *regArgs[]={ "rdi", "rsi", "rdx", "rcx", "r8", "r9"};
char nregArgs = sizeof(regArgs)/sizeof(char*);
 
int top = 0;
int nargs =0;
int nlabel = 0; // while label
int if_label = 0;
int for_label = 0;
int var_type;
int case_num = 0;

#define MAX_NAME 40
char loop_name[MAX_NAME];
char func_name[MAX_NAME];

int lookupGlobalVar(char* varName) {
   for(int i = 0; i < nglobals; i++) {
     if(strcmp(global_vars_table[i], varName) == 0) {
       return i;
     }
   }
   return -1;
}

int lookupLocalVar(char* varName) {
   for(int i = 0; i < nlocals; i++) {
     if(strcmp(local_vars_table[i], varName) == 0) {
       return i;
     }
   }
   return -1;
}

 void printLocalVar() {
   for(int i = 0; i < nlocals; i++) {
     printf("local variable: %s\n", local_vars_table[i]);
   }
 }
 
%}
   
%%
goal:   program
        ;
program :
        function_or_var_list;

function_or_var_list:
        function_or_var_list function
        | function_or_var_list global_var
| /*empty */
      ;

function:
         var_type WORD
         {
                 fprintf(fasm, "\t.text\n");
                 fprintf(fasm, ".globl %s\n", $2);
                 fprintf(fasm, "%s:\n", $2);
                 fprintf(fasm, "\t# Save Frame pointer\n");
                 fprintf(fasm, "\tpushq %%rbp\n");
                 fprintf(fasm, "\tmovq %%rsp,%%rbp\n");
                 fprintf(fasm, "# Save registers. \n");
                 fprintf(fasm, "# Push one extra to align stack to 16bytes\n");
                 fprintf(fasm, "\tpushq %%rbx\n");
                 fprintf(fasm, "\tpushq %%rbx\n");
                 fprintf(fasm, "\tpushq %%r10\n");
                 fprintf(fasm, "\tpushq %%r13\n");
                 fprintf(fasm, "\tpushq %%r14\n");
                 fprintf(fasm, "\tpushq %%r15\n");
		 
		 //reserve space for args and locals
		 fprintf(fasm, "\tsubq $%d, %%rsp\n", 8 * MAX_LOCALS);
		 nlocals = 0;
		 strcpy(func_name, $2);
		 
         }
LPARENT arguments RPARENT {
                 // save args 
                 for(int i = 0; i < nlocals; i ++) {
		   fprintf(fasm, "\tmovq %%%s, %d(%%rsp)\n", regArgs[i], 8 * i);
		 }
		 
         }
	 compound_statement
         {
	   fprintf(fasm, "\%s_end:\n", $2);
	   if(top > nregStk) {
	     // pop extra variable from operation stack
	     for(int i = 0; i < top - nregStk; i++) {
	       fprintf(fasm, "\tpopq %%rax\n");
	     }
	   }

	   // restore space in stack for local vars
	   fprintf(fasm, "\taddq $%d, %%rsp\n", 8 * MAX_LOCALS);
	   
                 fprintf(fasm, "# Restore registers\n");
                 fprintf(fasm, "\tpopq %%r15\n");
                 fprintf(fasm, "\tpopq %%r14\n");
                 fprintf(fasm, "\tpopq %%r13\n");
                 fprintf(fasm, "\tpopq %%r10\n");
                 fprintf(fasm, "\tpopq %%rbx\n");
                 fprintf(fasm, "\tpopq %%rbx\n");
                 fprintf(fasm, "\tleave\n");
                 fprintf(fasm, "\tret\n");
  }
  ;

arg_list:
         arg
         | arg_list COMA arg
         ;

arguments:
         arg_list
         | /*empty*/
         ;

arg: var_type WORD {
                local_vars_table[nlocals] = $<string_val>2;
		local_vars_type[nlocals] = var_type;
		nlocals++;
	 }
         ;



global_var:
        var_type global_var_list SEMICOLON;

global_var_list: WORD {
                 // reserve space for global variables
                 fprintf(fasm, "\t.data\n");
		 /*
		 fprintf(fasm, "%s:\n", $<string_val>1);
		 fprintf(fasm, "\t.long 0\n");
		 fprintf(fasm, "\t.long 0\n");
		 fprintf(fasm, "\n");
		 */
                 fprintf(fasm, "\t.comm %s, 8\n", $<string_val>1);
		 fprintf(fasm, "\n");
		 
		 global_vars_table[nglobals] = $<string_val>1;
		 global_vars_type[nglobals] = var_type;
		 nglobals++;  
        }
| global_var_list COMA WORD {
                 // reserve space for global variables
                 fprintf(fasm, "\t.data\n");
                 fprintf(fasm, "\t.comm %s, 8\n", $<string_val>3);
		 fprintf(fasm, "\n");
		 global_vars_table[nglobals] = $<string_val>3;
		 global_vars_type[nglobals] = var_type;
		 nglobals++;
        }
        ;

var_type: CHARSTAR {
            var_type = 0;
	}
        | CHARSTARSTAR {
	    var_type = 1;
	}
        | LONG {
	    var_type = 2;
        }
        | LONGSTAR {
	    var_type = 3;
        }
        | VOID {
	    var_type = 4;
        }
        ;

assignment:
WORD EQUAL expression {
                 // code for assignment
                 char * id = $<string_val>1;
		 int index = lookupLocalVar(id);
		 if(index >= 0) { // local variable
		   fprintf(fasm, "\t# save local variable\n");
		   if(top <= nregStk) { 
		     fprintf(fasm, "\tmovq %%%s, %d(%%rsp)\n", regStk[top-1], 8 * index);
		     top--;
		   }
		   else {
		     fprintf(fasm, "\tpopq %d(%%rsp)\n", 8 * index);
		     top--;
		     
		   }
		 }
		 else { // global variable
		   // save top of the stack in global var
		   if(top <= nregStk) {
		     fprintf(fasm, "\tmovq %%%s, %s\n", regStk[top-1], id);
		     top--;
		   }
		   else {
		     fprintf(fasm, "\tpopq %s\n", id);
		     top--;
		   }
		 }
        }
        | WORD LBRACE expression RBRACE EQUAL expression {
                 // code for assignment array
	         char * id = $<string_val>1;
		 int index = lookupLocalVar(id);
		 int skip;
		 if(index < 0) { // global
		   int i = lookupGlobalVar(id);
		   if(global_vars_type[i] == 0) { // char
		     skip = 1;
		   }
		   else {
		     skip = 8;
		   }

		   // regStk[top-1] contains value that will be assigned to
		   // a global variable, regStk[top-2] contains the offset of
		   // the entry (i in this case). so the value of regStk[top-1]
		   // are assigned to array[i], top will decrease by 2
		   if(top <= nregStk) {
		     fprintf(fasm, "\tleaq %s, %%rcx\n", id);
		     fprintf(fasm, "\tmovq %%%s, %%rax\n", regStk[top-2]);
		     fprintf(fasm, "\timulq $%d, %%rax\n", skip);
		     fprintf(fasm, "\taddq (%%rcx), %%rax\n");
		     fprintf(fasm, "\tmovq %%%s, (%%rax)\n", regStk[top-1]);
		     top = top - 2;
		   }
		   else if(top == nregStk + 1) {
		     fprintf(fasm, "\tleaq %s, %%rcx\n", id);
		     fprintf(fasm, "\tmovq %%%s, %%rax\n", regStk[top-2]);
		     fprintf(fasm, "\timulq $%d, %%rax\n", skip);
		     fprintf(fasm, "\taddq (%%rcx), %%rax\n");
		     fprintf(fasm, "\tpopq (%%rax)\n");
		     top = top - 2;
		   }
		   else {
		     fprintf(fasm, "\tleaq %s, %%rcx\n", id);
		     fprintf(fasm, "\tpopq %%rdx\n"); // equivelant to [top-1]
		     fprintf(fasm, "\tpopq %%rax\n"); // equivelant to [top-2]
		     fprintf(fasm, "\timulq $%d, %%rax\n", skip);
		     fprintf(fasm, "\taddq (%%rcx), %%rax\n");
		     fprintf(fasm, "\tmovq %%rdx, (%%rax)\n");
		     top = top - 2;
		   }
		 }
		 else { // local
		   if(local_vars_type[index] == 0) { // char
		     skip = 1;
		   }
		   else {
		     skip = 8;
		   }
		   // regStk[top-1] contains value that will be assigned to
		   // a local variable, regStk[top-2] contains the offset of
		   // the entry (i in this case). so the value of regStk[top-1]
		   // are assigned to array[i], top will decrease by 2
		   if(top <= nregStk) {
		     fprintf(fasm, "\tleaq %d(%%rsp), %%rcx\n", 8*index);
		     fprintf(fasm, "\tmovq %%%s, %%rax\n", regStk[top-2]);
		     fprintf(fasm, "\timulq $%d, %%rax\n", skip);
		     fprintf(fasm, "\taddq (%%rcx), %%rax\n");
		     fprintf(fasm, "\tmovq %%%s, (%%rax)\n", regStk[top-1]);
		     top = top - 2;
		   }
		   else if(top == nregStk + 1) {
		     fprintf(fasm, "\tleaq %d(%%rsp), %%rcx\n", 8*index);
		     fprintf(fasm, "\tmovq %%%s, %%rax\n", regStk[top-2]);
		     fprintf(fasm, "\timulq $%d, %%rax\n", skip);
		     fprintf(fasm, "\taddq (%%rcx), %%rax\n");
		     fprintf(fasm, "\tpopq (%%rax)\n");
		     top = top - 2;
		   }
		   else {
		     fprintf(fasm, "\tleaq %s, %%rcx\n", id);
		     fprintf(fasm, "\tpopq %%rdx\n"); // equivelant to [top-1]
		     fprintf(fasm, "\tpopq %%rax\n"); // equivelant to [top-2]
		     fprintf(fasm, "\timulq $%d, %%rax\n", skip);
		     fprintf(fasm, "\taddq (%%rcx), %%rax\n");
		     fprintf(fasm, "\tmovq %%rdx, (%%rax)\n");
		     top = top - 2;
		   }
		 }

        }
        ;

call :
         WORD LPARENT  call_arguments RPARENT {
  char * funcName = $<string_val>1;
                 int nargs = $<nargs>3;
                 int i;
                 fprintf(fasm,"     # func=%s nargs=%d\n", funcName, nargs);
                 fprintf(fasm,"     # Move values from reg stack to reg args\n");
		 
                 for (i=nargs-1; i>=0; i--) {
                        top--;

			if(top < nregStk) {
			  fprintf(fasm, "\tmovq %%%s, %%%s\n",
				  regStk[top], regArgs[i]);
			}
			else {
			  fprintf(fasm, "\tpopq %%%s\n", regArgs[i]);
			}
                 }
                 if (!strcmp(funcName, "printf")) {
                         // printf has a variable number of arguments           
                         // and it need the following                           
                         fprintf(fasm, "\tmovl    $0, %%eax\n");
                 }
		 
                 fprintf(fasm, "\tcall %s\n", funcName);

		 if(top < nregStk) {
		   fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top]);
		   top++;
		 }
		 else {
		   fprintf(fasm, "tpushq %%rax\n");
		   top++;
		 }
	 }
	 ;

call_arg_list:
         expression {
                $<nargs>$=1;
         }
         | call_arg_list COMA expression {
                $<nargs>$++;
         }
         ;

call_arguments:
         call_arg_list { $<nargs>$=$<nargs>1; }
         | /*empty*/ { $<nargs>$=0;}
         ;

expression :
         logical_or_expr
         ;

logical_or_expr:
         logical_and_expr
         | logical_or_expr OROR logical_and_expr {
                fprintf(fasm,"\n\t# ||\n");
				
                if (top<=nregStk) { //change from < to <=
		  fprintf(fasm, "\torq %%%s,%%%s\n",
                                regStk[top-1], regStk[top-2]);
		  top--;
                }
		else if(top = nregStk + 1) {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\torq %%rax, %%%s\n", regStk[top-2]);
		  top--;
		}
		else {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\torq %%rax, %%rcx\n");
		  fprintf(fasm, "\tpushq %%rcx\n");
		  top--;
		}  
		
	 }
         ;

logical_and_expr:
         equality_expr
         | logical_and_expr ANDAND equality_expr {
                fprintf(fasm,"\n\t# &&\n");
		
                if (top<=nregStk) { //change from < to <=
		  fprintf(fasm, "\tandq %%%s,%%%s\n",
                                regStk[top-1], regStk[top-2]);
		  top--;
                }
		else if(top = nregStk + 1) {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tandq %%rax, %%%s\n", regStk[top-2]);
		  top--;
		}
		else {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tandq %%rax, %%rcx\n");
		  fprintf(fasm, "\tpushq %%rcx\n");
		  top--;
		}  
		
	 }
         ;

equality_expr:
         relational_expr
         | equality_expr EQUALEQUAL relational_expr {
                fprintf(fasm,"\n\t# ==\n");

                if (top<=nregStk) { //change from < to <=
		  fprintf(fasm, "\tcmpq %%%s,%%%s\n",
                                regStk[top-1], regStk[top-2]);
		  fprintf(fasm, "\tsete %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
                }
		else if(top = nregStk + 1) {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tcmpq %%rax, %%%s\n", regStk[top-2]);
		  fprintf(fasm, "\tsete %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
		}
		else {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tpopq %%rcx\n");
		  fprintf(fasm, "\tcmpq %%rax %%rcx\n");
		  fprintf(fasm, "\tsete %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%rcx\n");
		  fprintf(fasm, "\tpushq %%rcx\n");
		  top--;
		}  
	 }
         | equality_expr NOTEQUAL relational_expr {
                fprintf(fasm,"\n\t# !=\n");

                if (top<=nregStk) { //change from < to <=
		  fprintf(fasm, "\tcmpq %%%s,%%%s\n",
                                regStk[top-1], regStk[top-2]);
		  fprintf(fasm, "\tsetne %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
                }
		else if(top = nregStk + 1) {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tcmpq %%rax, %%%s\n", regStk[top-2]);
		  fprintf(fasm, "\tsetne %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
		}
		else {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tpopq %%rcx\n");
		  fprintf(fasm, "\tcmpq %%rax %%rcx\n");
		  fprintf(fasm, "\tsetne %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%rcx\n");
		  fprintf(fasm, "\tpushq %%rcx\n");
		  top--;
		}  
	 }
         ;

relational_expr:
         additive_expr
         | relational_expr LESS additive_expr {
	        fprintf(fasm,"\n\t# <\n");

                if (top<=nregStk) { //change from < to <=
		  fprintf(fasm, "\tcmpq %%%s,%%%s\n",
                                regStk[top-1], regStk[top-2]);
		  fprintf(fasm, "\tsetl %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
                }
		else if(top = nregStk + 1) {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tcmpq %%rax, %%%s\n", regStk[top-2]);
		  fprintf(fasm, "\tsetl %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
		}
		else {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tpopq %%rcx\n");
		  fprintf(fasm, "\tcmpq %%rax %%rcx\n");
		  fprintf(fasm, "\tsetl %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%rcx\n");
		  fprintf(fasm, "\tpushq %%rcx\n");
		  top--;
		}  
	 }
         | relational_expr GREAT additive_expr {
                fprintf(fasm,"\n\t# >\n");

                if (top<=nregStk) { //change from < to <=
		  fprintf(fasm, "\tcmpq %%%s,%%%s\n",
                                regStk[top-1], regStk[top-2]);
		  fprintf(fasm, "\tsetg %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
                }
		else if(top = nregStk + 1) {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tcmpq %%rax, %%%s\n", regStk[top-2]);
		  fprintf(fasm, "\tsetg %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
		}
		else {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tpopq %%rcx\n");
		  fprintf(fasm, "\tcmpq %%rax %%rcx\n");
		  fprintf(fasm, "\tsetg %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%rcx\n");
		  fprintf(fasm, "\tpushq %%rcx\n");
		  top--;
		}  
	 }
         | relational_expr LESSEQUAL additive_expr {
                fprintf(fasm,"\n\t# <=\n");

                if (top<=nregStk) { //change from < to <=
		  fprintf(fasm, "\tcmpq %%%s,%%%s\n",
                                regStk[top-1], regStk[top-2]);
		  fprintf(fasm, "\tsetle %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
                }
		else if(top = nregStk + 1) {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tcmpq %%rax, %%%s\n", regStk[top-2]);
		  fprintf(fasm, "\tsetle %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
		}
		else {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tpopq %%rcx\n");
		  fprintf(fasm, "\tcmpq %%rax %%rcx\n");
		  fprintf(fasm, "\tsetle %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%rcx\n");
		  fprintf(fasm, "\tpushq %%rcx\n");
		  top--;
		}  
	 }
         | relational_expr GREATEQUAL additive_expr {
                fprintf(fasm,"\n\t# >=\n");

                if (top<=nregStk) { //change from < to <=
		  fprintf(fasm, "\tcmpq %%%s,%%%s\n",
                                regStk[top-1], regStk[top-2]);
		  fprintf(fasm, "\tsetge %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
                }
		else if(top = nregStk + 1) {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tcmpq %%rax, %%%s\n", regStk[top-2]);
		  fprintf(fasm, "\tsetge %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%%s\n", regStk[top-2]);
		  top--;
		}
		else {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tpopq %%rcx\n");
		  fprintf(fasm, "\tcmpq %%rax %%rcx\n");
		  fprintf(fasm, "\tsetge %%cl\n");
		  fprintf(fasm, "\tmovzbq %%cl, %%rcx\n");
		  fprintf(fasm, "\tpushq %%rcx\n");
		  top--;
		}  
	 }
         ;

additive_expr:
          multiplicative_expr
          | additive_expr PLUS multiplicative_expr {
                fprintf(fasm,"\n\t# +\n");

                if (top<=nregStk) { //change from < to <=
                        fprintf(fasm, "\taddq %%%s,%%%s\n",
                                regStk[top-1], regStk[top-2]);
                        top--;
                }
		else if(top = nregStk + 1) {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\taddq %%rax, %%%s\n", regStk[top-2]);
		  top--;
		}
		else {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tpopq %%rcx\n");
		  fprintf(fasm, "\taddq %%rax %%rcx\n");
		  fprintf(fasm, "\tpushq %%rcx\n");
		  top--;
		}
          }
          | additive_expr MINUS multiplicative_expr {
                  fprintf(fasm,"\n\t# -\n");

                  if (top<=nregStk) { //change from < to <=
		    fprintf(fasm, "\tsubq %%%s,%%%s\n",
			    regStk[top-1], regStk[top-2]);
		    top--;
		  }
		  else if(top = nregStk + 1) {
		    fprintf(fasm, "\tpopq %%rax\n");
		    fprintf(fasm, "\tsubq %%rax, %%%s\n", regStk[top-2]);
		    top--;
		  }
		  else {
		    fprintf(fasm, "\tpopq %%rax\n");
		    fprintf(fasm, "\tpopq %%rcx\n");
		    fprintf(fasm, "\tsubq %%rax %%rcx\n");
		    fprintf(fasm, "\tpushq %%rcx\n");
		    top--;
		  }
          }
          ;

multiplicative_expr:
          primary_expr
          | multiplicative_expr TIMES primary_expr {
                fprintf(fasm,"\n\t# *\n");

                  if (top<=nregStk) { //change from < to <=
		    fprintf(fasm, "\timulq %%%s,%%%s\n",
			    regStk[top-1], regStk[top-2]);
		    top--;
		  }
		  else if(top = nregStk + 1) {
		    fprintf(fasm, "\tpopq %%rax\n");
		    fprintf(fasm, "\timulq %%rax, %%%s\n", regStk[top-2]);
		    top--;
		  }
		  else {
		    fprintf(fasm, "\tpopq %%rax\n");
		    fprintf(fasm, "\tpopq %%rcx\n");
		    fprintf(fasm, "\timulq %%rax %%rcx\n");
		    fprintf(fasm, "\tpushq %%rcx\n");
		    top--;
		  }
		 
          }
          | multiplicative_expr DIVIDE primary_expr {
                fprintf(fasm,"\n\t# /\n");

                  if (top<=nregStk) { //change from < to <=
		    fprintf(fasm, "\tmovq %%%s,%%rax\n", regStk[top-2]);
		    fprintf(fasm, "\tcqto \t# covert quad to octal\n");
		    fprintf(fasm, "\tidivq %%%s\n", regStk[top-1]);
		    fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top-2]);
		    top--;
		  }
		  else if(top = nregStk + 1) {
		    fprintf(fasm, "\tmovq %%%s,%%rax\n", regStk[top-2]);
		    fprintf(fasm, "\tcqto \t# covert quad to octal\n");
		    fprintf(fasm, "\tpopq %%rcx\n");
		    fprintf(fasm, "\tidivq %%rcx\n");
		    fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top-2]);
		    top--;
		  }
		  else {
		    fprintf(fasm, "\tpopq %%rcx\n");
		    fprintf(fasm, "\tpopq %%rax\n");
		    fprintf(fasm, "\tcqto \t# covert quad to octal\n");
		    fprintf(fasm, "\tidivq %%rcx\n");
		    fprintf(fasm, "\tpushq %%rax\n");
		    top--;
		  }
	  }
	  
          | multiplicative_expr PERCENT primary_expr {
                fprintf(fasm,"\n\t# %% \n");

                  if (top<=nregStk) { //change from < to <=
		    fprintf(fasm, "\tmovq %%%s,%%rax\n", regStk[top-2]);
		    fprintf(fasm, "\tcqto \t# covert quad to octal\n");
		    fprintf(fasm, "\tidivq %%%s\n", regStk[top-1]);
		    fprintf(fasm, "\tmovq %%rdx, %%%s\n", regStk[top-2]);
		    top--;
		  }
		  else if(top = nregStk + 1) {
		    fprintf(fasm, "\tmovq %%%s,%%rax\n", regStk[top-2]);
		    fprintf(fasm, "\tcqto \t# covert quad to octal\n");
		    fprintf(fasm, "\tpopq %%rcx\n");
		    fprintf(fasm, "\tidivq %%rcx\n");
		    fprintf(fasm, "\tmovq %%rdx, %%%s\n", regStk[top-2]);
		    top--;
		  }
		  else {
		    fprintf(fasm, "\tpopq %%rcx\n");
		    fprintf(fasm, "\tpopq %%rax\n");
		    fprintf(fasm, "\tcqto \t# covert quad to octal\n");
		    fprintf(fasm, "\tidivq %%rcx\n");
		    fprintf(fasm, "\tpushq %%rdx\n");
		    top--;
		  }
	  }	  
          ;

primary_expr:
          STRING_CONST {
                  // Add string to string table.                                        
                  // String table will be produced later                                
                  string_table[nstrings]=$<string_val>1;
                  fprintf(fasm, "\t#top=%d\n", top);
                  fprintf(fasm, "\n\t# push string %s top=%d\n",
                          $<string_val>1, top);
                  if (top<nregStk) {
                        fprintf(fasm, "\tmovq $string%d, %%%s\n",
                                nstrings, regStk[top]);
                        //fprintf(fasm, "\tmovq $%s,%%%s\n",                            
                                //$<string_val>1, regStk[top]);                         
                        top++;
                  }

		  else {
		    //reg stack is full, push to execution stack
		    fprintf(fasm, "\tpushq $string%d\n", nstrings);
		    top++;
		    
		  }
		  
                  nstrings++;
          }
          | call
          | WORD {
                  // Assume it is a global variable                                     
                  // TODO: Implement also local variables      
                  char * id = $<string_val>1;

		  int index = lookupLocalVar(id);
		  if(index < 0) { //read global variable and push to stacks
		    if(top < nregStk) {
		      fprintf(fasm, "\tmovq %s,%%%s\n", id, regStk[top]);
		      top++;
		    }
		    else{
		      fprintf(fasm, "tpushq %s\n", id);
		      top++;
		    }
		  }
		  else { // read local variable and push to stacks
		    fprintf(fasm, "\t# get local variable\n");
		    if(top < nregStk) {
		      fprintf(fasm, "\tmovq %d(%%rsp), %%%s\n", 8 * index, regStk[top]);
		      top++;
                      
		    }
		    else {
		      fprintf(fasm, "\tpushq %d(%%rsp)\n", 8 * index);
		      top++;
		    }

		  }
		  
          }
          | WORD LBRACE expression RBRACE {
	    // todo: this is for array
	    char * id = $<string_val>1;
	    int index = lookupLocalVar(id);
	    int skip;
	    if(index < 0) { // global variable
	      int i = lookupGlobalVar(id);
	      if(global_vars_type[i] == 0) { // char array
		skip = 1;
	      }
	      else {
		skip = 8;
	      }

	      // get address of global variable (a pointer),
	      // no need to do top++
	      // because it pop some ingeter i from stack and
	      // push array[i] back to stack
	      if(top <= nregStk) {
		fprintf(fasm, "\tleaq %s, %%rcx\n", id);
		fprintf(fasm, "\tmovq %%%s, %%rax\n", regStk[top-1]);
		fprintf(fasm, "\timulq $%d, %%rax\n", skip);
		fprintf(fasm, "\taddq (%%rcx), %%rax\n");
		if(skip == 8) {
		  fprintf(fasm, "\tmovq (%%rax), %%%s\n", regStk[top-1]);
		}
		else {
		  fprintf(fasm, "\tmovq $0, %%rdx\n");
		  fprintf(fasm, "\tmovb (%%rax), %%dl\n");
		  fprintf(fasm, "\tmovq %%rdx, %%%s\n", regStk[top-1]);
		}
	      }
	      else {
		fprintf(fasm, "\tleaq %s, %%rcx\n", id);
		fprintf(fasm, "\tpopq %%rax\n");
		fprintf(fasm, "\timulq $%d, %%rax\n", skip);
		fprintf(fasm, "\taddq (%%rcx), %%rax\n");
		if(skip == 8) {
		  fprintf(fasm, "\tpushq (%%rax)\n");
		}
		else {
		  fprintf(fasm, "\tmovq $0, %%rdx\n");
		  fprintf(fasm, "\tmovb (%%rax), %%dl\n");
		  fprintf(fasm, "\tpushq %%rdx\n");
		}
	      }
	    }
	    else {
	      if(local_vars_type[index] == 0) {
		skip = 1;
	      }
	      else {
		skip = 8;
	      }
	      // get address of local variable (a pointer),
	      // no need to do top++
	      // because it pop some ingeter i from stack and
	      // push array[i] back to stack
	      if(top <= nregStk) {
		fprintf(fasm, "\tleaq %d(%%rsp), %%rcx\n", index*8);
		fprintf(fasm, "\tmovq %%%s, %%rax\n", regStk[top-1]);
		fprintf(fasm, "\timulq $%d, %%rax\n", skip);
		fprintf(fasm, "\taddq (%%rcx), %%rax\n");
		if(skip == 8) {
		  fprintf(fasm, "\tmovq (%%rax), %%%s\n", regStk[top-1]);
		}
		else {
		  fprintf(fasm, "\tmovq $0, %%rdx\n");
		  fprintf(fasm, "\tmovb (%%rax), %%dl\n");
		  fprintf(fasm, "\tmovq %%rdx, %%%s\n", regStk[top-1]);
		}
	      }
	      else {
		fprintf(fasm, "\tleaq %d(%%rsp), %%rcx\n", index*8);
		fprintf(fasm, "\tpopq %%rax\n");
		fprintf(fasm, "\timulq $%d, %%rax\n", skip);
		fprintf(fasm, "\taddq (%%rcx), %%rax\n");
		if(skip == 8) {
		  fprintf(fasm, "\tpushq (%%rax)\n");
		}
		else {
		  fprintf(fasm, "\tmovq $0, %%rdx\n");
		  fprintf(fasm, "\tmovb (%%rax), %%dl\n");
		  fprintf(fasm, "\tpushq %%rdx\n");
		}
	      }
	    }
	   	    
	  }
          | AMPERSAND WORD { 
			// todo: this is for address of
	    char * id = $<string_val>2;
	    int index = lookupLocalVar(id);
	    if(index < 0) { // global
	      if(top < nregStk) {
		fprintf(fasm, "\tleaq %s, %%%s\n", id, regStk[top]);
		top++;
	      }
	      else {
		fprintf(fasm, "\tleaq %s, %%rax\n", id);
		fprintf(fasm, "\tpushq %%rax\n");
		top++;
	      }
	    }
	    else { // local
	      if(top < nregStk) {
		fprintf(fasm, "\tleaq %d(%%rsp), %%%s\n", 8*index, regStk[top]);
		top++;
	      }
	      else {
		fprintf(fasm, "\tleaq %d(%%rsp), %%rax\n", 8*index);
		fprintf(fasm, "\tpushq %%rax\n");
		top++;
	      }
	    }
	  }
          | INTEGER_CONST {
                  fprintf(fasm, "\n\t# push %s\n", $<string_val>1);
                  if (top<nregStk) {
                        fprintf(fasm, "\tmovq $%s,%%%s\n",
                                $<string_val>1, regStk[top]);
                        top++;
		  }
		  else {
		    fprintf(fasm, "\tpush $%s\n", $<string_val>1);
		  }
          }
          | LPARENT expression RPARENT
          ;

compound_statement:
         LCURLY statement_list RCURLY
         ;

statement_list:
         statement_list statement
         | /*empty*/
         ;

local_var:
        var_type local_var_list SEMICOLON;
local_var_list: WORD {
               local_vars_table[nlocals] = $<string_val>1;
	       local_vars_type[nlocals] = var_type;
	       nlocals++;
	}
        | local_var_list COMA WORD {
               local_vars_table[nlocals] = $<string_val>3;
	       local_vars_type[nlocals] = var_type;
	       nlocals++;
	}
        ;

statement:
         assignment SEMICOLON
         | call SEMICOLON { top= 0; /* Reset register stack */ }
         | local_var
         | compound_statement
         | IF LPARENT {
	     // add if label
	     $<my_nlabel>1 = if_label;
	     if_label++;
	     fprintf(fasm, "if_%d:\n", $<my_nlabel>1);
	   
	   }
           expression RPARENT {
	      if(top <= nregStk) {
		fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
		fprintf(fasm, "\tje else_%d\n", $<my_nlabel>1); // false case
		top--;
	      }
	      else {
		fprintf(fasm, "\tpopq %%rax\n");
		fprintf(fasm, "\tcmpq $0, %%rax\n");
		fprintf(fasm, "\tje else_%d\n", $<my_nlabel>1); // false case
		top--;
	      }
           }
           statement {
	     fprintf(fasm, "\tjmp after_if_%d\n", $<my_nlabel>1);
	     fprintf(fasm, "else_%d:\n", $<my_nlabel>1);
           }
           else_optional {
	     fprintf(fasm, "after_if_%d:\n", $<my_nlabel>1);
           }
         | WHILE LPARENT {
                // act 1                                                                
                $<my_nlabel>1=nlabel;
                nlabel++;
		strcpy(loop_name, "while");
                fprintf(fasm, "while_start_%d:\n", $<my_nlabel>1);
         }
         expression RPARENT {
                // act2
	        if(top <= nregStk) {
		  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
		  fprintf(fasm, "\tje while_end_%d\n", $<my_nlabel>1); // false case
		  top--;
		}
		else {
		  fprintf(fasm, "\tpopq %%rax\n");
		  fprintf(fasm, "\tcmpq $0, %%rax\n");
		  fprintf(fasm, "\tje while_end_%d\n", $<my_nlabel>1);
		  top--;
		}
	 }
         statement {
                // act3                                                                 
                fprintf(fasm, "\tjmp while_start_%d\n", $<my_nlabel>1);
                fprintf(fasm, "while_end_%d:\n", $<my_nlabel>1);
         }
         | DO {
	        $<my_nlabel>1=nlabel;
		nlabel++;
	        strcpy(loop_name, "while");
                fprintf(fasm, "while_start_%d:\n", $<my_nlabel>1);
         }
         statement WHILE LPARENT expression RPARENT SEMICOLON {
	   if(top <= nregStk) {
	     fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
	     fprintf(fasm, "\tje while_end_%d\n", $<my_nlabel>1); // false case
	     fprintf(fasm, "\tjmp while_start_%d\n", $<my_nlabel>1);
	     top--;
	   }
	   else {
	     fprintf(fasm, "\tpopq %%rax\n");
	     fprintf(fasm, "\tcmpq $0, %%rax\n");
	     fprintf(fasm, "\tje while_end_%d\n", $<my_nlabel>1);
	     fprintf(fasm, "\tjmp while_start_%d\n", $<my_nlabel>1);
	     top--;
	   }
	   fprintf(fasm, "while_end_%d:\n", $<my_nlabel>1);
	 }
         | FOR LPARENT assignment SEMICOLON {
	   $<my_nlabel>1 = for_label;
	   for_label++;
	   strcpy(loop_name, "for");
	   fprintf(fasm, "for_start_%d:\n", $<my_nlabel>1);		   
	 }
         expression SEMICOLON {
	   if(top <= nregStk) {
	     
	     fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
	     fprintf(fasm, "\tje for_end_%d\n", $<my_nlabel>1);
	     fprintf(fasm, "\tjmp for_body_%d\n", $<my_nlabel>1);
	     top--;
	   }
	   else {
	     fprintf(fasm, "\tpopq %%rax\n");
	     fprintf(fasm, "\tcmpq $0, %%rax\n");
	     fprintf(fasm, "\tje for_end_%d\n", $<my_nlabel>1);
	     fprintf(fasm, "\tjmp for_body_%d\n", $<my_nlabel>1);
	     top--;
	   }
	   fprintf(fasm, "for_assign_%d:\n", $<my_nlabel>1);
	   
         }assignment RPARENT {
	   fprintf(fasm, "\tjmp for_start_%d\n",  $<my_nlabel>1);
	   fprintf(fasm, "for_body_%d:\n",  $<my_nlabel>1);
	   
         }
         statement {
	   fprintf(fasm, "\tjmp for_assign_%d\n",  $<my_nlabel>1);
	   fprintf(fasm, "for_end_%d:\n",  $<my_nlabel>1);
         }
         | jump_statement
	 | switch_statement
         ;

else_optional:
         ELSE  statement
         | /* empty */
         ;



/******** switch ********/
switch_statement:
         SWITCH LPARENT expression {
	   
	   strcpy(loop_name, "switch");
	   fprintf(fasm, "\tmovq %%%s, %%rax\n", regStk[top-1]);
	   fprintf(fasm, "case_%d:\n", case_num);

         } RPARENT LCURLY case_list {

	   
         } DEFAULT COLON statement BREAK SEMICOLON {

	   fprintf(fasm, "after_switch:\n");
	   
         } RCURLY;


case_list:
         case_item /* At least one */
         | case_list case_item;

case_item:
         CASE expression COLON {
	   
	   case_num++;
	   fprintf(fasm, "\tcmpq %%%s, %%rax\n", regStk[top-1]);
	   fprintf(fasm, "\tjne case_%d\n", case_num);
	   
         } statement BREAK SEMICOLON {

	   fprintf(fasm, "\tjmp after_switch\n");
	   fprintf(fasm, "case_%d:\n", case_num);
         };


jump_statement:
         CONTINUE SEMICOLON {
	
	   if(strcmp(loop_name, "while") == 0) {
	     fprintf(fasm, "\tjmp while_start_%d\n", nlabel-1); 
	   }
	   else {
	     fprintf(fasm, "\tjmp for_assign_%d\n", for_label-1);
	   }
         }
         | BREAK SEMICOLON {
	   if(strcmp(loop_name, "while") == 0) {
	     fprintf(fasm, "\tjmp while_end_%d\n", nlabel-1); 
	   }
	   else if(strcmp(loop_name, "for") == 0) {
	     fprintf(fasm, "\tjmp for_end_%d\n", for_label-1);
	   }
	   else {
	     fprintf(fasm, "\tjmp after_switch\n");
	   }
         }
         | RETURN expression SEMICOLON {
	   if(top <= nregStk) {  
	     fprintf(fasm, "\tmovq %%%s, %%rax\n", regStk[top-1]);
	     top = 0;
	   }
	   else {
	     fprintf(fasm, "\tpopq %%rax\n");
	     top = 0;
	   }
	   fprintf(fasm, "\tjmp %s_end\n", func_name);
         }
         ;
%%

void yyset_in (FILE *  in_str );
int
yyerror(const char * s)
{
        fprintf(stderr,"%s:%d: %s\n", input_file, line_number, s);
}
int
main(int argc, char **argv)
{
        printf("-------------WARNING: You need to implement global and local vars -----\
-\n");
        printf("------------- or you may get problems with top------\n");
        // Make sure there are enough arguments                                         
        if (argc <2) {
                fprintf(stderr, "Usage: simple file\n");
                exit(1);
        }
        // Get file name                                                                
        input_file = strdup(argv[1]);
        int len = strlen(input_file);
        if (len < 2 || input_file[len-2]!='.' || input_file[len-1]!='c') {
                fprintf(stderr, "Error: file extension is not .c\n");
                exit(1);
        }
        // Get assembly file name                                                       
        asm_file = strdup(input_file);
        asm_file[len-1]='s';
        // Open file to compile                                                         
        FILE * f = fopen(input_file, "r");
        if (f==NULL) {
                fprintf(stderr, "Cannot open file %s\n", input_file);
                perror("fopen");
		exit(1);
 }
        // Create assembly file                                                         
        fasm = fopen(asm_file, "w");
        if (fasm==NULL) {
                fprintf(stderr, "Cannot open file %s\n", asm_file);
                perror("fopen");
                exit(1);
        }
        // Uncomment for debugging                                                      
        //fasm = stderr;                                                                
        // Create compilation file                                                      
        //                                                                              
        yyset_in(f);
        yyparse();
        // Generate string table                                                        
        int i;
        for (i = 0; i<nstrings; i++) {
                fprintf(fasm, "string%d:\n", i);
                fprintf(fasm, "\t.string %s\n\n", string_table[i]);
        }
	
        fclose(f);
	fclose(fasm);
	
        return 0;
}
