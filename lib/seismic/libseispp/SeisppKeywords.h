#ifndef _SEISPP_KEYWORDS_H_
#define _SEISPP_KEYWORDS_H_
#include <string>
namespace SEISPP {
using namespace std;
/* 
*  The first block of keywords are VERY critical to any entity
*  that inhereits a BasicTimeSeries aimed to be read 
*  from a database. The keywords used here match exactly the
*  standard attribute names for these quantities in the css3.0
*  schema used in Antelope.  If this library is used for a different
*  database schema with different names, it would be easiest to implement
*  the change with an ifdef block here that would changes these constants.
*/

/*! Keyword for number of samples for a BasicTimeSeries.  */
const string number_samples_keyword("nsamp");
/*! Keyword for start time (t0) of a BasicTimeSeries. */
const string start_time_keyword("time");
/*! Keyword for end time of a BasicTimeSeries. */
const string end_time_keyword("endtime");
/*! Keyword for sample rate of a BasicTimeSeries. */
const string sample_rate_keyword("samprate");
/*! Keyword for timetype (relative or absolute) attribute.*/
const string timetype_keyword("timetype");
/*
*   END BasicTimeSeries keyword block
*/

/*! Defines keyword for gain factor.   

Normally this is calib of the raw data, although other algorithms could alter it.
The basic concept is that the original recorded amplitude can be restored by 
dividing each sample by this factor. */
const string gain_keyword("gain");
/*! Defines if data is calibrated.

This is a boolean key that is set true if the associated data has a
known response and is calibrated such that calib and the gain_keyword
entry mean something.  If false it means the amplitude of the data 
are arbitrary numbers that cannot be linked to physical units. */
const string calibrated_keyword("calibrated");
/*! Defines a keyword to reference moveout used by the generalized stack operator.*/
const string moveout_keyword("moveout"); 
/*! Defines keyword for coherence estimate for generalized stack operator. */
const string coherence_keyword("coherence"); 
/*! Defines keyword for amplitude stack estimate for MultichannelCorrelator operator.*/
const string amplitude_static_keyword("amplitude_static");
/*! Defines keyword for weight used for robust stack estimate in generalized stack operator. */
const string stack_weight_keyword("stack_weight");
/*! Defines keyword for a predicted arrival time. */
const string predicted_time_key("predarr_time");
/*! Defines keyword for a generic measured arrival time. Phase type is normally a different attribute.*/
const string arrival_time_key("arrival_time");
/*! Defines keyword for an arrival time extracted from a database.  This may or may not
match an attibute stored with the arrival_time_keyword.  It is sometimes useful to have
both attributes loaded. */
const string dbarrival_time_key("arrival.time");
/*! rms amplitude of a stack (beam).  Units depend on data.*/
const string beam_rms_key("beam_rms");
/*! Keyword used to store a signal to noise ratio estimate.  

Signal to noise ratio is something commonly required in signal processing.
This attribute is used to store such an estimate.  The method is not 
specified, but if it is necessary to distiguish the method it is assumed
another keyword will be used or the another attribute posted to quality 
the type of estimate stored with this name. */
const string snr_keyword("signal_to_noise_ratio");
/*! Keyword to post signal to noise ratio in db.  

  Signal to noise ratio can vary over orders of magnitude so it is
  often preferable to post values in db to, for example, plot 
  variable snr data and see something. */
const string snrdb_keyword("snr_in_db");
/*!  Peak cross correlation ratio metric.  
  
  Used in XcorProcessingEngine to post the ratio of the peak 
  cross-correlation to the second largest peak. 
  */
const string XcorPeakRatioKeyword("xcor_peak_ratio");
/*! Used to flag a moveout estimate as bad.  Set to this large value. */
const double MoveoutBad=1.0e10;
/*! A test for a bad moveout value uses this number.  It is intentionally much
smaller than MoveoutBad for safety sake. */
const double MoveoutBadTest=1.0e8; 
};
#endif
