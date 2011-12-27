/* *********************** *
 * Parametric Equalizer    *
 * J. Colosimo             *
 * 6.111 - Fall '10        *
 * debounce.v              *
 * debounce module         *
 * *********************** */

/* this is the button debounce module from many labs throughout the course */

///////////////////////////////////////////////////////////////////////////////
//
// Button Debounce Module
//
///////////////////////////////////////////////////////////////////////////////

module debounce (reset, clock, noisy, clean);

   input reset, clock, noisy;
   output clean;

   reg [18:0] count;
   reg new, clean;

   always @(posedge clock)
     if (reset)
       begin
	  count <= 0;
	  new <= noisy;
	  clean <= noisy;
       end
     else if (noisy != new)
       begin
	  new <= noisy;
	  count <= 0;
       end
     else if (count == 270000)
       clean <= new;
     else
       count <= count+1;
      
endmodule

