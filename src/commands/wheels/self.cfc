component  extends="base"  {
    /*
    @name  greeting 
*/

	function run( string name = "developers" ) {
		
        // header -name od self 
       
        print.boldRedLine(" /\ ---")
        .boldRedLine("A T  I F R A O")
        .yellowLine("welcome,#name#")
        .yellowBoldLine( "Current Working Directory: #getCWD()#");
      
		}
    }

