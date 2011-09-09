package bamtools;

import net.sf.picard.cmdline.CommandLineProgram;
import net.sf.picard.cmdline.Option;
import net.sf.picard.cmdline.StandardOptionDefinitions;
import net.sf.picard.cmdline.Usage;
import net.sf.picard.io.IoUtil;
import net.sf.samtools.*;

import java.io.File;
import java.io.IOException;

/**
 * Class to fix CIGAR for BAMs generated by BWA. Current implementation 
 * resets CIGARs to * and sets mapping quality to zero for unmapped reads.
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class CIGARFixer extends CommandLineProgram
{
  @Usage
   public String USAGE = getStandardUsagePreamble() +
   "Read SAM/BAM and perform modify CIGAR and mapping quality. \r\n" +
   "For unmapped reads, reset CIGAR to * and mapping quality to zero.";

  @Option(shortName = StandardOptionDefinitions.INPUT_SHORT_NAME, doc = "Input SAM/BAM to be cleaned.")
  public File INPUT;

  @Option(shortName = StandardOptionDefinitions.OUTPUT_SHORT_NAME, optional=true,
          doc = "Where to write cleaned SAM/BAM. If not specified, replaces original input file.")
  public File OUTPUT;
  
  public static void main(String[] args)
  {
    new CIGARFixer().instanceMainWithExit(args);
  }
  
  /**
   * Method to do the actual work.
   */
  @Override
  protected int doWork()
  {
    try
    {
      IoUtil.assertFileIsReadable(INPUT);
      int numReadsProcessed = 0;
      
      if(OUTPUT != null) OUTPUT = OUTPUT.getAbsoluteFile();
      
      final boolean differentOutputFile = OUTPUT != null;
      
      if(differentOutputFile) IoUtil.assertFileIsWritable(OUTPUT);
      else
      {
        createTempFile();
      }
      SAMFileReader.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);
      SAMFileReader reader = new SAMFileReader(INPUT);
      SAMFileWriter writer = new
      SAMFileWriterFactory().makeSAMOrBAMWriter(reader.getFileHeader(), true, OUTPUT);
      SAMRecord rec = null;
      
      SAMRecordIterator it = reader.iterator();
      while(it.hasNext())
      {
        numReadsProcessed++;
        if(numReadsProcessed % 10000000 == 0)
        {
          System.err.print("Processed : " + numReadsProcessed + " reads\r");
        }
        rec = it.next();
        writer.addAlignment(SAMRecordFixer.fixCIGARForUnmappedReads(rec));
      }
      writer.close();
      reader.close();
      it.close();
      
      if(differentOutputFile) return 0;
      else return replaceInputFile();
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
      return -1;
    }
  }

  /**
   * Helper method to create a temporary file to write fixed bam/sam
   * @throws IOException
   */
  private void createTempFile() throws IOException
  {
    final File inputFile = INPUT.getAbsoluteFile();
    final File inputDir  = inputFile.getParentFile().getAbsoluteFile();
	    
    IoUtil.assertFileIsWritable(inputFile);
    IoUtil.assertDirectoryIsWritable(inputDir);
    OUTPUT = File.createTempFile(inputFile.getName()+ "_being_fixed", ".bam", inputDir);
  }
  
  /**
   * Helper method to replace the original input file with the fixed file
   * @return
   */
  private int replaceInputFile()
  {
    final File inputFile = INPUT.getAbsoluteFile();
    final File oldFile = new File(inputFile.getParentFile(), inputFile.getName() + ".old");
    
    if(!oldFile.exists() && inputFile.renameTo(oldFile))
    {
      if(OUTPUT.renameTo(inputFile))
      {
        if(!oldFile.delete())
        {
          System.err.println("Could not delete old file : " + oldFile.getAbsolutePath());
          return 1;
        }
      }
      else
      {
        System.err.println("Could not move temp file to : " + inputFile.getAbsolutePath());
        System.err.println("Input file preserved as : " + oldFile.getAbsolutePath());
        System.err.println("New file preserved as : " + OUTPUT.getAbsolutePath());
        return 1;
      }
    }
    else
    {
      System.err.println("Could not move input file : " + inputFile.getAbsolutePath());
      System.err.println("New file preserved as : " + OUTPUT.getAbsolutePath());
      return 1;
    }
    return 0;
  }
}