
 add_fsm_encoding \
       {DF_Wishbone_Interface.Output_Unit.ControlPath.State} \
       { }  \
       {{0000 0000000000000001} {0001 0000000000000010} {0010 0000000000000100} {0011 0000000000001000} {0100 0000000000010000} {0101 0000000000100000} {0110 0000000010000000} {0111 0000000100000000} {1000 0000001000000000} {1001 0000010000000000} {1010 1000000000000000} {1011 0010000000000000} {1100 0100000000000000} {1101 0000100000000000} {1110 0000000001000000} {1111 0001000000000000} }

 add_fsm_encoding \
       {DF_Wishbone_Interface.Input_Unit.ControlPath.State} \
       { }  \
       {{0000 0000} {0001 0001} {0010 0010} {0011 0011} {0100 0100} {0101 0101} {0110 0110} {0111 0111} {1000 1000} {1001 1001} {1010 1010} {1011 1011} {1100 1100} {1101 1101} }

 add_fsm_encoding \
       {Serieller_Empfaenger.Steuerwerk.Zustand} \
       { }  \
       {{0000 000} {0001 001} {0010 010} {0011 011} {0100 101} {0101 110} {0110 111} {0111 100} }

 add_fsm_encoding \
       {Serieller_Sender.Steuerwerk.Zustand} \
       { }  \
       {{000 000} {001 001} {010 010} {011 011} {100 100} {101 101} }

 add_fsm_encoding \
       {wb_ds_textdisplay_v1_0.state} \
       { }  \
       {{0000 0000} {0001 0001} {0010 0010} {0011 0011} {0100 1000} {0101 0100} {0110 0101} {0111 0111} {1000 0110} }

 add_fsm_encoding \
       {ds_video_out_v1_0.hor_state} \
       { }  \
       {{000 00} {001 01} {010 10} {011 11} }

 add_fsm_encoding \
       {ds_video_out_v1_0.ver_state} \
       { }  \
       {{000 001} {001 010} {010 011} {011 100} {100 000} }