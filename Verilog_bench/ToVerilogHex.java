import java.io.*;

public class ToVerilogHex {
	public static void main(String[] args) {
		try {
			if(args.length < 2) {
				System.out.println("ToVerilogHex [infile] [outfile]");
				System.exit(1);
			}
			byte[] image = new byte[1024];
			FileInputStream fis = new FileInputStream(new File(args[0]));
			fis.read(image);
			BufferedWriter bw = new BufferedWriter(new FileWriter(new File(args[1])));
			for(int i = 0; i < image.length; i+=2) {
				bw.write(String.format("%02x%02x", image[i+1] & 0xFF, image[i] & 0xFF));
				bw.newLine();
			}
			fis.close();
			bw.close();
		}catch(Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}
}
