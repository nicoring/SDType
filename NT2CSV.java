import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileReader;
import java.io.FileWriter;
import java.util.StringTokenizer;

public class NT2CSV {
	
	// the path that contains the files instance-types.nt and mappingbased-properties.nt
	// TODO put in your path
	// TODO change the language prefix in both inFiles and outFiles
	private static String folder = "PATH_TO_YOUR_DATA";

	/**
	 * @param args
	 */
	public static void main(String[] args) throws Exception {
		convertTypeFile();
		convertMappingBasedPropertiesOnlyDBpedia();
	}
	
	private static void convertTypeFile() throws Exception {
		String inFile = folder + "/instance_types_prefix.nt";
		String outFile = folder + "/instance_types_prefix.csv";
		
		BufferedReader reader = new BufferedReader(new FileReader(inFile));
		BufferedWriter writer = new BufferedWriter(new FileWriter(outFile));
		
		long lines = 0;
		while(reader.ready()) {
			String s = reader.readLine();
			if(s.startsWith("#"))
				continue;
			// the following does not work
			// s = s.replaceAll("'", "\\'");
			// workaround:
			while(s.indexOf("'")>s.indexOf("\\'")+1)
				s = s.replace("'","\\'");

			s = s.replaceAll(" <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> ", ",");
			s = s.replaceAll("<","'");
			s = s.replaceAll(">", "'");
			s = s.replaceAll(" .", "");
			writer.write(s + System.getProperty("line.separator"));
			if(++lines%1000000==0)
				System.out.println(lines + " lines processed");
		}
		writer.flush();
		writer.close();
		reader.close();
	}

	private static void convertMappingBasedPropertiesOnlyDBpedia() throws Exception {
		String inFile = folder + "/mappingbased_properties_prefix.nt";
		String outFile = folder + "/mappingbased_properties_prefix.csv";
		
		BufferedReader reader = new BufferedReader(new FileReader(inFile));
		BufferedWriter writer = new BufferedWriter(new FileWriter(outFile));
		
		long lines = 0;
		while(reader.ready()) {
			String s = reader.readLine();
			if(s.startsWith("#"))
				continue;
			// the following does not work
			// s = s.replaceAll("'", "\\'");
			// workaround:
			String line = "";
			StringTokenizer stk = new StringTokenizer(s,"> ",false);
			String subject = stk.nextToken();
			while(subject.indexOf("'")>subject.indexOf("\\'")+1)
				subject = subject.replace("'","\\'");
			subject = subject.replace("<","");
			line += "'" + subject + "',";

			String predicate = stk.nextToken();
			while(predicate.indexOf("'")>predicate.indexOf("\\'")+1)
				predicate = predicate.replace("'","\\'");
			predicate = predicate.replace("<","");
			line += "'" + predicate + "',";
			
			String object = stk.nextToken();
			if(object.startsWith("<")) {
				boolean dbpediaResource = object.startsWith("<http://dbpedia.org/resource/");
				if(dbpediaResource) {
					object = object.replace(" .","");
					while(object.indexOf("'")>object.indexOf("\\'")+1)
						object = object.replace("'","\\'");
					object = object.replace("<","");
					line += "'" + object+ "'";
					writer.write(line + System.getProperty("line.separator"));
				}
				if(++lines%1000000==0)
					System.out.println(lines + " lines processed");
			}
			
		}
		writer.flush();
		writer.close();
		reader.close();
	}
}
