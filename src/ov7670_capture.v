//============================================================================
// Module: ov7670_capture
// Description: OV7670 Pixel Capture - RGB565 to RGB444
//
// OV7670 ส่ง RGB565 เป็น 2 bytes ต่อ pixel ทาง PCLK:
//   PCLK1 → Byte1 = [R4 R3 R2 R1 R0 G5 G4 G3]
//   PCLK2 → Byte2 = [G2 G1 G0 B4 B3 B2 B1 B0]
//
// ใช้ byte_sel toggle แทน wr_hold pipeline
// byte_sel=0 → รับ Byte1, byte_sel=1 → รับ Byte2 แล้ว write
// Reset byte_sel ทุก href rising edge เพื่อให้ phase ถูกเสมอ
//============================================================================

module ov7670_capture (
    input  wire        pclk,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  d,
    output wire [16:0] addr,
    output wire [11:0] dout,
    output reg         we
);

    reg [7:0]  byte1;       // เก็บ Byte1 ไว้รอ
    reg        byte_sel;    // 0=รอ Byte1, 1=รอ Byte2
    reg        href_prev;
    reg [11:0] dout_reg;

    reg [9:0] x;
    reg [9:0] y;

    assign addr = y * 320 + x;
    assign dout = dout_reg;

    always @(posedge pclk) begin
        if (vsync) begin
            x         <= 0;
            y         <= 0;
            we        <= 0;
            byte_sel  <= 0;
            href_prev <= 0;
            byte1     <= 0;
        end else begin
            href_prev <= href;
            we        <= 0;  // default: no write

            // Reset phase ทุก href rising edge
            if (href && !href_prev)
                byte_sel <= 0;

            if (href) begin
                if (byte_sel == 0) begin
                    // รับ Byte1: [R4 R3 R2 R1 R0 G5 G4 G3]
                    byte1    <= d;
                    byte_sel <= 1;
                end else begin
                    // รับ Byte2: [G2 G1 G0 B4 B3 B2 B1 B0]
                    // แปลง RGB565 → RGB444: เอา 4 bits บนของแต่ละ channel
                    // RGB565: R[4:0]=byte1[7:3], G[5:0]={byte1[2:0],d[7:5]}, B[4:0]=d[4:0]
                    // RGB444: R[3:0]=R[4:1]=byte1[7:4], G[3:0]=G[5:2]={byte1[2:0],d[7]}, B[3:0]=B[4:1]=d[4:1]
                    dout_reg <= {
                        byte1[7:4],          // R[4:1] → R444 upper 4 bits
                        byte1[2:0], d[7],    // G[5:2] → G444 upper 4 bits
                        d[4:1]               // B[4:1] → B444 upper 4 bits
                    };
                    we       <= 1;
                    byte_sel <= 0;

                    // Increment position
                    if (x < 319) begin
                        x <= x + 1;
                    end else begin
                        x <= 0;
                        if (y < 239)
                            y <= y + 1;
                        else
                            y <= 0;
                    end
                end
            end
        end
    end

endmodule