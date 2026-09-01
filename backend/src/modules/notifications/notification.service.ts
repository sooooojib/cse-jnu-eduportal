import { query } from '../../config/database';
import { NotFoundError } from '../../common/errors';

export interface NotificationDto {
  id: string;
  title: string;
  body: string;
  notificationType: string;
  referenceType: string | null;
  referenceId: string | null;
  isRead: boolean;
  createdAt: string;
}

export interface NotificationFeedDto {
  unreadCount: number;
  notifications: NotificationDto[];
}

export class NotificationService {
  async getNotifications(userId: string): Promise<NotificationFeedDto> {
    const unreadRes = await query<{ count: string }>(
      `SELECT COUNT(*) as count FROM notifications WHERE user_id = $1 AND is_read = false`,
      [userId]
    );
    const unreadCount = parseInt(unreadRes.rows[0].count, 10);

    const notifRes = await query<{
      id: string;
      title: string;
      body: string;
      notification_type: string;
      reference_type: string | null;
      reference_id: string | null;
      is_read: boolean;
      created_at: Date;
    }>(
      `SELECT 
        id, 
        title, 
        body, 
        notification_type, 
        reference_type, 
        reference_id, 
        is_read, 
        created_at 
       FROM notifications 
       WHERE user_id = $1 
       ORDER BY created_at DESC 
       LIMIT 50`,
      [userId]
    );

    const notifications: NotificationDto[] = notifRes.rows.map((n) => ({
      id: n.id,
      title: n.title,
      body: n.body,
      notificationType: n.notification_type,
      referenceType: n.reference_type,
      referenceId: n.reference_id,
      isRead: n.is_read,
      createdAt: n.created_at.toISOString(),
    }));

    return {
      unreadCount,
      notifications,
    };
  }

  async markAsRead(userId: string, notificationId: string): Promise<void> {
    const res = await query(
      `UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2`,
      [notificationId, userId]
    );

    if (res.rowCount === 0) {
      throw new NotFoundError('Notification not found.');
    }
  }

  async markAllAsRead(userId: string): Promise<void> {
    await query(`UPDATE notifications SET is_read = true WHERE user_id = $1`, [userId]);
  }
}

export const notificationService = new NotificationService();
