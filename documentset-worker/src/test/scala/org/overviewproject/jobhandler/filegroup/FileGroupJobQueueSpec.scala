package org.overviewproject.jobhandler.filegroup

import scala.concurrent.duration._
import org.specs2.mutable.Specification
import org.overviewproject.test.ActorSystemContext
import org.specs2.mutable.Before
import org.overviewproject.jobhandler.filegroup.FileGroupTaskWorkerProtocol._
import org.overviewproject.jobhandler.filegroup.FileGroupJobQueueProtocol._
import akka.testkit._
import org.specs2.time.NoTimeConversions
import akka.actor.ActorRef
import akka.actor.ActorSystem
import org.overviewproject.jobhandler.filegroup.ProgressReporterProtocol._

class FileGroupJobQueueSpec extends Specification with NoTimeConversions {

  "FileGroupJobQueue" should {

    "notify registered workers when tasks becomes available" in new JobQueueContext {
      fileGroupJobQueue ! RegisterWorker(worker.ref)

      submitJob

      worker.expectMsg(TaskAvailable)
    }

    "send available tasks to workers that ask for them" in new JobQueueContext {
      val workers = createNWorkers(numberOfUploadedFiles)
      workers.foreach(w => fileGroupJobQueue ! RegisterWorker(w.ref))

      submitJob
      val receivedTasks = expectTasks(workers)
      mustMatchUploadedFileIds(receivedTasks, uploadedFileIds)
    }

    "notify worker if tasks are available when it registers" in new JobQueueContext {
      submitJob
      fileGroupJobQueue ! RegisterWorker(worker.ref)

      worker.expectMsg(TaskAvailable)
    }

    "don't send anything if no tasks are available" in new JobQueueContext {
      fileGroupJobQueue ! RegisterWorker(worker.ref)
      fileGroupJobQueue.tell(ReadyForTask, worker.ref)

      worker.expectNoMsg(500 millis)
    }

    "notify requester when all tasks for a fileGroupId are complete" in new JobQueueContext {
      ActAsImmediateJobCompleter(worker)
      submitJob

      fileGroupJobQueue ! RegisterWorker(worker.ref)

      expectMsg(FileGroupDocumentsCreated(documentSetId))
    }

    "ignore a second job for the same fileGroup" in new JobQueueContext {
      fileGroupJobQueue ! RegisterWorker(worker.ref)
      
      submitJob
      worker.expectMsg(TaskAvailable)
      
      submitJob
      worker.expectNoMsg(500 millis)
      
    }
    
    "report progress" in new JobQueueContext {
      ActAsImmediateJobCompleter(worker)
      fileGroupJobQueue ! RegisterWorker(worker.ref)
      submitJob
      
      progressReporter.expectMsg(StartJob(documentSetId, numberOfUploadedFiles))
      val progressMessages = progressReporter.receiveN(2 * numberOfUploadedFiles)

      val expectedStartTasks = uploadedFileIds.map { StartTask(documentSetId, _) }
      val expectedCompleteTask = uploadedFileIds.map { CompleteTask(documentSetId, _) }
      
      progressMessages must containTheSameElementsAs(expectedStartTasks ++ expectedCompleteTask)
      
      progressReporter.expectMsg(CompleteJob(documentSetId))
    }
    
    "handle cancellations" in {
      todo
    }

    abstract class JobQueueContext extends ActorSystemContext with Before {
      protected val documentSetId = 1l
      protected val fileGroupId = 2l
      protected val numberOfUploadedFiles = 10
      protected val uploadedFileIds: Seq[Long] = Seq.tabulate(numberOfUploadedFiles)(_.toLong)

      protected var fileGroupJobQueue: ActorRef = _
      protected var worker: TestProbe = _
      protected var progressReporter: TestProbe = _
      
      def before = {
        progressReporter = TestProbe()
        fileGroupJobQueue = system.actorOf(TestFileGroupJobQueue(uploadedFileIds, progressReporter.ref))
        worker = TestProbe()
      }

      protected def createNWorkers(numberOfWorkers: Int): Seq[WorkerTestProbe] =
        Seq.fill(numberOfWorkers)(new WorkerTestProbe(fileGroupId, system))

      protected def submitJob =
        fileGroupJobQueue ! CreateDocumentsFromFileGroup(documentSetId, fileGroupId)

      protected def expectTasks(workers: Seq[WorkerTestProbe]) = workers.map { _.expectATask }
      
      protected def mustMatchUploadedFileIds(tasks: Seq[CreatePagesTask], uploadedFileIds: Seq[Long]) =
    		  tasks.map(_.uploadedFileId) must containTheSameElementsAs(uploadedFileIds)        
    }

    class WorkerTestProbe(fileGroupId: Long, actorSystem: ActorSystem)
        extends TestProbe(actorSystem) {
      def expectATask = {
        expectMsg(TaskAvailable)
        reply(ReadyForTask)

        expectMsgClass(classOf[CreatePagesTask])
      }
    }

    class ImmediateJobCompleter(worker: ActorRef) extends TestActor.AutoPilot {
      def run(sender: ActorRef, message: Any): TestActor.AutoPilot = {
        message match {
          case TaskAvailable => sender.tell(ReadyForTask, worker)
          case CreatePagesTask(ds, fg, uf) => {
            sender.tell(CreatePagesTaskDone(ds, fg, uf), worker)
            sender.tell(ReadyForTask, worker)
          }
        }
        TestActor.KeepRunning
      }
    }

    object ActAsImmediateJobCompleter {
      def apply(probe: TestProbe): TestProbe = {
        probe.setAutoPilot(new ImmediateJobCompleter(probe.ref))
        probe
      }
    }
  }
}