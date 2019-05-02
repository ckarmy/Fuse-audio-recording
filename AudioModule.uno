using Uno;
using Uno.UX;
using Uno.Collections;
using Fuse;
using Uno.Threading;
using Fuse.Scripting;
using Uno.Compiler.ExportTargetInterop;
using Uno.Permissions;

namespace Test.Audio
{
	[UXGlobalModule]
	public class Audio: NativeModule
	{
		static readonly Audio _instance;
		public Audio(){
			if (_instance != null) return;
			_instance = this;
			Resource.SetGlobalKey(_instance, "AudioRecorder");
			AddMember( new NativeFunction("recordAudio", (NativeCallback)RecordAudio) );
			AddMember( new NativeFunction("isRecording", (NativeCallback)IsRecording) );
			AddMember( new NativeFunction("stopAudio", (NativeCallback)StopAudio) );
			AddMember( new NativeFunction("playAudio", (NativeCallback)PlayAudio) );
		}

		object RecordAudio(Context c, object[] args)
		{
			if defined(Android)
			{
				AudioRecordImplement.getInstance().Record();
			}
			return null;
		}

		object IsRecording(Context c, object[] args)
		{
			if defined(Android)
				return AudioRecordImplement.getInstance().IsRecording();
			return false;
		}

		object StopAudio(Context c, object[] args)
		{
			if defined(Android)
				return AudioRecordImplement.getInstance().Stop();
			return null;
		}

		object PlayAudio(Context c, object[] args)
		{
			if defined(Android)
				return AudioRecordImplement.getInstance().Play();
			return null;
		}
	}

	[ForeignInclude(Language.Java,"android.media.MediaPlayer","android.media.MediaRecorder","android.os.Bundle","android.widget.Toast","android.os.Environment","java.io.IOException")]
	extern(Android) class AudioRecordImplement
	{

		Java.Object _handle;
		string _outputFile;
		bool _started;
		static AudioRecordImplement _instance;

		private AudioRecordImplement()
		{
			_handle = InitMediaRecorder();
		}

		public static AudioRecordImplement getInstance() {
			if (_instance == null)
				_instance = new AudioRecordImplement();
			return _instance;
		}

		[Foreign(Language.Java)]
		public Java.Object InitMediaRecorder()
		@{
			MediaRecorder myAudioRecorder = new MediaRecorder();
			return myAudioRecorder;
		@}

		public void Record()
		{
			var permissions = new PlatformPermission[]
			{
				Permissions.Android.RECORD_AUDIO,
				Permissions.Android.WRITE_EXTERNAL_STORAGE,
				Permissions.Android.READ_EXTERNAL_STORAGE
			};

			Permissions.Request(permissions).Then(OnPermitted, OnRejected);
		}

		public bool IsRecording() {
			return _started;
		}

		void OnPermitted(PlatformPermission[] permissions)
	    {
	    	if (permissions.Length == 3)
	        	_outputFile = Record(_handle);
	    }

	    void OnRejected(Exception e)
	    {
	        debug_log "Error: " + e.Message;
	    }

		[Foreign(Language.Java)]
		extern(Android) string Record(Java.Object handle)
		@{
			String outputFile = com.fuse.Activity.getRootActivity().getExternalCacheDir().getAbsolutePath();
			outputFile += "/testAudio.3gp";
			try {
				MediaRecorder myAudioRecorder = (MediaRecorder)handle;
				myAudioRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
				myAudioRecorder.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP);
				myAudioRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);
				myAudioRecorder.setOutputFile(outputFile);
				myAudioRecorder.prepare();
				myAudioRecorder.start();
				@{AudioRecordImplement:Of(_this)._started:Set(true)};
				com.fuse.Activity.getRootActivity().runOnUiThread(new Runnable() {
					@Override
			        public void run() {
			            Toast.makeText(com.fuse.Activity.getRootActivity(), "Audio Recorder start", Toast.LENGTH_LONG).show();
			        }
				});
			} catch (IllegalStateException ise) {
				outputFile = null;
				android.util.Log.d("FuseTest", ise.getMessage());
			} catch (IOException ioe) {
				outputFile = null;
				android.util.Log.d("FuseTest", ioe.getMessage());
			} catch (Exception e) {
				outputFile = null;
				android.util.Log.d("FuseTest", e.getMessage());
			}
			return outputFile;
		@}

		public bool Stop()
		{
			if (_started)
				return Stop(_handle);
			return false;
		}

		[Foreign(Language.Java)]
		extern(Android) bool Stop(Java.Object handle)
		@{
			MediaRecorder myAudioRecorder = (MediaRecorder)handle;
			myAudioRecorder.stop();
			myAudioRecorder.release();
			myAudioRecorder = null;
			@{AudioRecordImplement:Of(_this)._started:Set(false)};
			com.fuse.Activity.getRootActivity().runOnUiThread(new Runnable() {
				@Override
		        public void run() {
		            Toast.makeText(com.fuse.Activity.getRootActivity(), "Audio Recorder stop", Toast.LENGTH_LONG).show();
		        }
			});
			return true;
		@}

		public bool Play()
		{
			if (_outputFile != null)
				return Play(_outputFile);
			return false;
		}

		[Foreign(Language.Java)]
		static extern(Android) bool Play(string outputFile)
		@{
			MediaPlayer mediaPlayer = new MediaPlayer();
			try {
				mediaPlayer.setDataSource(outputFile);
				mediaPlayer.prepare();
				mediaPlayer.start();
				com.fuse.Activity.getRootActivity().runOnUiThread(new Runnable() {
					@Override
			        public void run() {
			            Toast.makeText(com.fuse.Activity.getRootActivity(), "Playing Audio", Toast.LENGTH_LONG).show();
			        }
				});
			} catch (Exception e) {
					// make something
				return false;
			}
			return true;
		@}
	}
}