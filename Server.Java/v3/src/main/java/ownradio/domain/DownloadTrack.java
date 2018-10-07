package ownradio.domain;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.Type;

import javax.persistence.*;
import java.util.UUID;

/**
 * Сущность для хранения информации о скаченных треках
 *
 * @author Alpenov Tanat
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "downloadtracks")
public class DownloadTrack extends AbstractEntity {
	@ManyToOne
	@JoinColumn(name = "deviceid")
	private Device device;

	@ManyToOne
	@JoinColumn(name = "trackid")
	private Track track;

	private Integer methodid;

	@Type(type="pg-uuid")
	@Column(columnDefinition = "uuid")
	private UUID userrecommendid;

	private String txtrecommendinfo;

}
