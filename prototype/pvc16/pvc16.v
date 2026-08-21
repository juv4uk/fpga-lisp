// PVC-16: 16-bit Phonetic Vector Code Module for FPGA Lisp
// Single-cycle Savarna (1.1.9) comparator and Sandhi Voicing logic.

module pvc16_core (
    input  wire [15:0] sound_a,
    input  wire [15:0] sound_b,
    output wire        is_vowel_a,
    output wire        is_vowel_b,
    output wire        is_savarna,
    output wire [15:0] voiced_a,
    output wire [15:0] unvoiced_a
);

    // Bitfield breakdown:
    // [0]    : Vowel flag (1 = ac, 0 = hal)
    // [5:1]  : Sthana (1=Kanthya, 2=Talavya, 3=Murdhanya, 4=Dantya, 5=Oshthya)
    // [9:6]  : Prayatna (6=Sprsta/Stop, 7=Mahaprana/Asp, 8=Ghosha/Voiced, 9=Anunasika)
    // [13:10]: Svara / Length (10-11=Hrasva/Dirgha/Pluta, 12-13=Udatta/Anudatta/Svarita)
    // [15:14]: Modifiers (14=Palatalized soft [ь], 15=Dipthong/Extension)

    assign is_vowel_a = sound_a[0];
    assign is_vowel_b = sound_b[0];

    // Sutra 1.1.9: tulyasyaprayatnam savarnam
    // Same Sthana (bits 5:1) AND same internal effort (Spriṣṭa bit 6, Vowel bit 0)
    wire same_sthana   = (sound_a[5:1] == sound_b[5:1]) && (sound_a[5:1] != 5'b00000);
    wire same_prayatna = (sound_a[6] == sound_b[6]) && (sound_a[0] == sound_b[0]);

    assign is_savarna = same_sthana && same_prayatna;

    // Single-cycle Voicing / Devoicing
    assign voiced_a   = sound_a | 16'h0100;  // Set bit 8 (Ghosha)
    assign unvoiced_a = sound_a & ~16'h0100; // Clear bit 8

endmodule
