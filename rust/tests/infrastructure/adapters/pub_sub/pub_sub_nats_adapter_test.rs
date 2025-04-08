use rustbot::domain::ports::pub_sub::PubSub;
use rustbot::infrastructure::adapters::pub_sub::pub_sub_nats_adapter::NatsPubSub;
use std::error::Error;
use std::sync::Arc;
use tokio::sync::mpsc;
use tokio::time::{sleep, Duration};

#[tokio::test]
async fn test_publish_and_subscribe() -> Result<(), Box<dyn Error>> {
    // Connect to a test NATS server
    let server_url = "nats://localhost:4222";

    // Create a publisher and subscriber
    let publisher = NatsPubSub::new(server_url).await?;
    let subscriber = NatsPubSub::new(server_url).await?;

    // Create a channel to receive messages
    let (tx, mut rx) = mpsc::channel(1);
    let tx = Arc::new(tx);

    // Subscribe to the test subject
    let subject = "test.subject";
    subscriber
        .subscribe(
            subject,
            Arc::new(move |payload| {
                let tx = tx.clone();
                tokio::spawn(async move {
                    tx.send(payload).await.unwrap();
                });
                Ok(())
            }),
        )
        .await?;

    // Give some time for the subscription to be established
    sleep(Duration::from_millis(100)).await;

    // Publish a test message
    let test_payload = b"Hello, NATS!";
    publisher.publish(subject, test_payload).await?;

    // Wait for the message to be received
    let received_payload = rx.recv().await.unwrap();
    assert_eq!(received_payload, test_payload);

    Ok(())
}

#[tokio::test]
async fn test_multiple_subscribers() -> Result<(), Box<dyn Error>> {
    // Connect to a test NATS server
    let server_url = "nats://localhost:4222";

    // Create a publisher and two subscribers
    let publisher = NatsPubSub::new(server_url).await?;
    let subscriber1 = NatsPubSub::new(server_url).await?;
    let subscriber2 = NatsPubSub::new(server_url).await?;

    // Create channels to receive messages
    let (tx1, mut rx1) = mpsc::channel(1);
    let (tx2, mut rx2) = mpsc::channel(1);
    let tx1 = Arc::new(tx1);
    let tx2 = Arc::new(tx2);

    // Subscribe both subscribers to the same subject
    let subject = "test.subject";
    subscriber1
        .subscribe(
            subject,
            Arc::new(move |payload| {
                let tx = tx1.clone();
                tokio::spawn(async move {
                    tx.send(payload).await.unwrap();
                });
                Ok(())
            }),
        )
        .await?;

    subscriber2
        .subscribe(
            subject,
            Arc::new(move |payload| {
                let tx = tx2.clone();
                tokio::spawn(async move {
                    tx.send(payload).await.unwrap();
                });
                Ok(())
            }),
        )
        .await?;

    // Give some time for the subscriptions to be established
    sleep(Duration::from_millis(100)).await;

    // Publish a test message
    let test_payload = b"Hello, NATS!";
    publisher.publish(subject, test_payload).await?;

    // Wait for both subscribers to receive the message
    let received_payload1 = rx1.recv().await.unwrap();
    let received_payload2 = rx2.recv().await.unwrap();
    assert_eq!(received_payload1, test_payload);
    assert_eq!(received_payload2, test_payload);

    Ok(())
}
