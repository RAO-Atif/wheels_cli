component  extends="base"  {
    /*
    @name  greeting 
*/

	function run( string name = "developers" ) {
		
        // header -name od self 
       
        print.boldRedLine(" /\ ---")
        .boldRedLine("Y O U A R E R A O")
        .yellowLine("welcome,#name#")
        .yellowBoldLine( "Current Working Directory: #getCWD()#")
        .yellowBoldLine("CommandBox Module Root: #expandPath("/wheels-cli/")#");
		}
    }
